import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/id_generator.dart';
import '../models/user_session.dart';
import '../models/business_profile.dart';
import '../services/session_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/otp_service.dart';
import '../database/database_helper.dart';

class AuthRepository {
  final FirebaseAuth? _firebaseAuth;
  final SessionService _sessionService;
  final CloudSyncService _cloudSync;
  final OtpService _otpService;

  String? _lastVerificationId;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    SessionService? sessionService,
    CloudSyncService? cloudSync,
    OtpService? otpService,
  })  : _firebaseAuth = firebaseAuth,
        _sessionService = sessionService ?? SessionService(),
        _cloudSync = cloudSync ?? CloudSyncService(),
        _otpService = otpService ?? OtpService(firebaseAuth: firebaseAuth);

  FirebaseAuth? get _auth {
    if (_firebaseAuth != null) return _firebaseAuth;
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance;
      }
    } catch (_) {}
    return null;
  }

  UserSession? get currentUser => _sessionService.currentUser;
  bool get isLoggedIn => _sessionService.isLoggedIn;
  bool get isOnboardingDone => _sessionService.isOnboardingDone;
  bool get isBusinessSetupDone => _sessionService.isBusinessSetupDone;
  String? get currentVerificationId => _lastVerificationId;

  @visibleForTesting
  OtpService get otpService => _otpService;

  String _normalizeMobile(String mobile) {
    String cleaned = mobile.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  /// Checks if an account exists for this mobile number in the cloud registry.
  Future<bool> checkAccountExists(String mobile) async {
    final clean = _normalizeMobile(mobile);
    if (clean.length != 10) return false;
    return _cloudSync.isAccountRegistered(clean);
  }

  /// Pre-registers / stages account information before sending OTP.
  Future<void> preRegisterAccount({
    required String mobile,
    required String ownerName,
    required String businessName,
    String? email,
    String? businessType,
  }) async {
    final clean = _normalizeMobile(mobile);
    if (clean.length != 10) {
      throw ValidationException('Please enter a valid 10-digit mobile number.');
    }

    final exists = await checkAccountExists(clean);
    if (exists) {
      throw AuthException('An account already exists for this number. Please log in instead.');
    }

    await _cloudSync.preRegisterPendingAccount(
      mobile: clean,
      ownerName: ownerName,
      businessName: businessName,
      email: email,
      businessType: businessType,
    );
  }

  /// Sends a real OTP to the provided 10-digit mobile number.
  /// Enforces that Login fails if the user does NOT exist, and Create Account fails if the user ALREADY exists.
  Future<String> sendOtp(
    String mobile, {
    bool isNewAccount = false,
    bool forceResend = false,
    void Function(String verificationId)? onCodeSent,
    void Function(String error)? onError,
  }) async {
    final clean = _normalizeMobile(mobile);
    if (clean.length != 10) {
      throw ValidationException('Please enter a valid 10-digit mobile number.');
    }

    // 1. FLOW INTEGRITY: Enforce account existence check BEFORE sending OTP
    if (!isNewAccount) {
      // LOGIN: Account MUST exist. Unregistered users MUST NOT receive OTP or reach OTP screen!
      final exists = await checkAccountExists(clean);
      if (!exists) {
        throw AuthException('Account not found. Please create an account first.');
      }
    } else {
      // CREATE ACCOUNT: Account MUST NOT already exist
      final exists = await checkAccountExists(clean);
      if (exists) {
        throw AuthException('An account already exists for this number. Please log in instead.');
      }
    }

    // 2. Dispatch OTP via OtpService
    try {
      final vid = await _otpService.sendOtp(
        mobile: clean,
        forceResend: forceResend,
        onCodeSent: onCodeSent,
        onError: onError,
      );
      _lastVerificationId = vid;
      return vid;
    } on AuthException {
      rethrow;
    } catch (e) {
      final message = _mapError(e);
      onError?.call(message);
      throw AuthException(message);
    }
  }

  /// Verifies the entered 6-digit OTP and establishes the authenticated user session.
  /// Strict verification: Never hardcodes OTP, never bypasses verification.
  Future<UserSession> verifyOtpAndLogin({
    required String mobile,
    required String otp,
    bool isNewAccount = false,
    String? verificationId,
    String? ownerName,
    String? businessName,
    String? email,
    String? businessType,
  }) async {
    final cleanOtp = otp.trim();
    if (cleanOtp.length != 6 || int.tryParse(cleanOtp) == null) {
      throw ValidationException('Please enter the complete 6-digit OTP.');
    }

    final clean = _normalizeMobile(mobile);
    if (clean.length != 10) {
      throw ValidationException('Please enter a valid 10-digit mobile number.');
    }

    // 1. Verify OTP using OtpService (Strict Dynamic Verification)
    final effectiveVerId = verificationId ?? _lastVerificationId;
    await _otpService.verifyOtp(
      mobile: clean,
      otp: cleanOtp,
      verificationId: effectiveVerId,
    );

    // 2. Enforce Flow Integrity Based on Registration Status
    if (!isNewAccount) {
      final exists = await checkAccountExists(clean);
      if (!exists) {
        throw AuthException('Account not found. Please create an account first.');
      }
    }

    // 3. Resolve user UID and session details
    String uid = '';
    final authInstance = _auth;
    if (authInstance?.currentUser != null) {
      uid = authInstance!.currentUser!.uid;
    } else {
      final existingUid = await _cloudSync.getUidForMobile(clean);
      uid = (existingUid != null && existingUid.isNotEmpty)
          ? existingUid
          : 'usr_${IdGenerator.generateId()}';
    }

    Map<String, dynamic>? profile;
    if (!isNewAccount) {
      profile = await _cloudSync.getAccountProfile(uid) ??
          await _cloudSync.getAccountProfileByMobile(clean);
    } else {
      profile = await _cloudSync.getAccountProfileByMobile(clean);
    }

    final resolvedOwner = (ownerName != null && ownerName.isNotEmpty)
        ? ownerName
        : (profile?['ownerName'] ?? 'Store Owner');
    final resolvedBusiness = (businessName != null && businessName.isNotEmpty)
        ? businessName
        : (profile?['businessName'] ?? 'SCANZO Store');
    final resolvedEmail = email ?? profile?['email'];

    final session = UserSession(
      id: uid,
      ownerName: resolvedOwner,
      businessName: resolvedBusiness,
      mobile: clean,
      email: resolvedEmail,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Persist session
    await _sessionService.saveSession(session);

    // Register in persistent cloud registry
    await _cloudSync.registerAccount(
      uid: session.id,
      mobile: clean,
      ownerName: resolvedOwner,
      businessName: resolvedBusiness,
      email: resolvedEmail,
    );

    // Scope active database to this user UID
    await DatabaseHelper().setActiveUserId(session.id);

    // If new account, ensure initial business profile is created with selected shop type
    if (isNewAccount && DatabaseHelper().businessProfile == null) {
      final initialStore = BusinessProfile(
        id: 'store_${DateTime.now().millisecondsSinceEpoch % 10000}',
        userId: session.id,
        businessName: resolvedBusiness,
        ownerName: resolvedOwner,
        mobile: clean,
        email: resolvedEmail,
        address: 'Main Store',
        city: 'City',
        state: 'State',
        pincode: '000000',
        shopTypeId: (businessType ?? profile?['businessType'] ?? 'retail').toLowerCase().replaceAll(' ', '_'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await DatabaseHelper().saveBusinessProfile(initialStore);
    }

    return session;
  }

  /// Restores session on app startup by checking saved session or Firebase currentUser.
  Future<bool> restoreSessionOnStartup() async {
    final localUser = _sessionService.currentUser;
    if (localUser != null && localUser.id.isNotEmpty) {
      final hasProfile = await _cloudSync.hasAccountProfile(localUser.id);
      if (hasProfile) {
        await DatabaseHelper().setActiveUserId(localUser.id);
        return true;
      }
    }

    final authInstance = _auth;
    final firebaseUser = authInstance?.currentUser;

    if (firebaseUser != null) {
      final uid = firebaseUser.uid;
      final hasProfile = await _cloudSync.hasAccountProfile(uid);

      if (hasProfile) {
        final profile = await _cloudSync.getAccountProfile(uid);
        final cleanMobile = _normalizeMobile(firebaseUser.phoneNumber ?? profile?['mobile'] ?? '');
        final session = UserSession(
          id: uid,
          ownerName: profile?['ownerName'] ?? 'Store Owner',
          businessName: profile?['businessName'] ?? 'SCANZO Store',
          mobile: cleanMobile,
          email: profile?['email'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _sessionService.saveSession(session);
        await DatabaseHelper().setActiveUserId(uid);
        return true;
      }
    }

    if (authInstance != null && firebaseUser == null) {
      await _sessionService.logout();
      await DatabaseHelper().setActiveUserId('');
    }
    return false;
  }

  Future<void> completeOnboarding() async {
    await _sessionService.markOnboardingCompleted();
  }

  Future<void> completeBusinessSetup() async {
    await _sessionService.markBusinessSetupCompleted();
  }

  Future<void> logout() async {
    try {
      await _auth?.signOut();
    } catch (_) {}
    await _sessionService.logout();
    await DatabaseHelper().setActiveUserId('');
  }

  String _mapError(dynamic error) {
    String code = '';
    if (error is FirebaseAuthException) {
      code = error.code.toLowerCase().trim();
    } else {
      final str = error.toString().toLowerCase();
      final match = RegExp(r'(?:firebase_auth\/|auth\/)([a-z0-9\-]+)').firstMatch(str);
      if (match != null) {
        code = match.group(1)!;
      }
    }

    switch (code) {
      case 'invalid-phone-number':
        return 'Please enter a valid 10-digit mobile number.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check the code and try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new OTP.';
      case 'network-request-failed':
        return 'Unable to send OTP. Please try again.';
      case 'quota-exceeded':
      case 'billing-not-enabled':
      case 'captcha-check-failed':
      case 'app-not-authorized':
      case 'unauthorized-domain':
      case 'operation-not-allowed':
      case 'invalid-app-credential':
      case 'invalid-api-key':
      case 'api-key-not-valid':
        return 'Unable to send OTP. Please try again.';
      default:
        return 'Unable to send OTP. Please try again.';
    }
  }
}
