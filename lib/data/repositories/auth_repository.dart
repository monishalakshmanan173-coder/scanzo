import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/id_generator.dart';
import '../models/user_session.dart';
import '../models/business_profile.dart';
import '../services/session_service.dart';
import '../services/cloud_sync_service.dart';
import '../database/database_helper.dart';

class AuthRepository {
  final FirebaseAuth? _firebaseAuth;
  final SessionService _sessionService;
  final CloudSyncService _cloudSync;

  // In-flight phone verification tokens
  String? _lastVerificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmationResult;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    SessionService? sessionService,
    CloudSyncService? cloudSync,
  })  : _firebaseAuth = firebaseAuth,
        _sessionService = sessionService ?? SessionService(),
        _cloudSync = cloudSync ?? CloudSyncService();

  FirebaseAuth? get _auth {
    if (_firebaseAuth != null) return _firebaseAuth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  UserSession? get currentUser => _sessionService.currentUser;
  bool get isLoggedIn => _sessionService.isLoggedIn;
  bool get isOnboardingDone => _sessionService.isOnboardingDone;
  bool get isBusinessSetupDone => _sessionService.isBusinessSetupDone;
  String? get currentVerificationId => _lastVerificationId;

  /// Checks if an account exists for this mobile number in the cloud registry.
  Future<bool> checkAccountExists(String mobile) async {
    return _cloudSync.isAccountRegistered(mobile);
  }

  /// Sends a real SMS OTP to the provided 10-digit mobile number using Firebase Authentication.
  /// Dispatches real SMS OTP across all legitimate mobile numbers.
  Future<String> sendOtp(
    String mobile, {
    bool isNewAccount = false,
    void Function(String verificationId)? onCodeSent,
    void Function(String error)? onError,
  }) async {
    // 1. Sanitize and normalize mobile number (handle +91, 91 prefix, leading 0)
    String cleaned = mobile.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.length != 10) {
      throw ValidationException('Please enter a valid 10-digit mobile number.');
    }

    final formattedNumber = '+91$cleaned';
    final authInstance = _auth;

    if (authInstance != null) {
      try {
        if (kIsWeb) {
          // Web Phone Authentication (supports reCAPTCHA and custom/Vercel domains)
          final confirmationResult = await authInstance.signInWithPhoneNumber(
            formattedNumber,
          );
          _webConfirmationResult = confirmationResult;
          _lastVerificationId = confirmationResult.verificationId;
          onCodeSent?.call(confirmationResult.verificationId);
          return confirmationResult.verificationId;
        } else {
          // Android & iOS Native Phone Authentication using Completer to await codeSent
          final completer = Completer<String>();

          await authInstance.verifyPhoneNumber(
            phoneNumber: formattedNumber,
            timeout: const Duration(seconds: 60),
            verificationCompleted: (PhoneAuthCredential credential) async {
              // Auto-retrieval handled seamlessly on supported Android devices
            },
            verificationFailed: (FirebaseAuthException e) {
              final message = _mapFirebaseError(e);
              onError?.call(message);
              if (!completer.isCompleted) {
                completer.completeError(AuthException(message));
              }
            },
            codeSent: (String verificationId, int? resendToken) {
              _lastVerificationId = verificationId;
              _resendToken = resendToken;
              onCodeSent?.call(verificationId);
              if (!completer.isCompleted) {
                completer.complete(verificationId);
              }
            },
            codeAutoRetrievalTimeout: (String verificationId) {
              _lastVerificationId = verificationId;
              if (!completer.isCompleted) {
                completer.complete(verificationId);
              }
            },
            forceResendingToken: _resendToken,
          );

          return await completer.future.timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              if (_lastVerificationId != null && _lastVerificationId!.isNotEmpty) {
                return _lastVerificationId!;
              }
              throw AuthException('SMS sending timed out. Please check your network and try again.');
            },
          );
        }
      } on FirebaseAuthException catch (e) {
        final message = _mapFirebaseError(e);
        onError?.call(message);
        throw AuthException(message);
      } catch (e) {
        if (e is AuthException) rethrow;
        final message = _mapFirebaseError(e);
        onError?.call(message);
        throw AuthException(message);
      }
    } else {
      // Offline / Test environment fallback
      _lastVerificationId = 'test_ver_${IdGenerator.generateId()}';
      onCodeSent?.call(_lastVerificationId!);
      return _lastVerificationId!;
    }
  }

  /// Verifies the entered 6-digit OTP using Firebase Authentication and establishes the user session.
  /// - Enforces that Login fails if no store profile exists for this UID.
  /// - Enforces that Create Account registers the profile permanently with Firebase UID.
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
    if (cleanOtp.length != 6) {
      throw ValidationException('Please enter the complete 6-digit OTP.');
    }

    final authInstance = _auth;
    String uid = '';
    String? phoneNumber;

    if (authInstance != null) {
      try {
        if (kIsWeb && _webConfirmationResult != null) {
          final userCredential = await _webConfirmationResult!.confirm(cleanOtp);
          final user = userCredential.user;
          if (user == null) {
            throw AuthException('Authentication failed. No user record returned.');
          }
          uid = user.uid;
          phoneNumber = user.phoneNumber;
        } else {
          final effectiveVerId = verificationId ?? _lastVerificationId;
          if (effectiveVerId == null || effectiveVerId.isEmpty) {
            throw AuthException('Verification session expired. Please request a new OTP.');
          }

          final credential = PhoneAuthProvider.credential(
            verificationId: effectiveVerId,
            smsCode: cleanOtp,
          );

          final userCredential = await authInstance.signInWithCredential(credential);
          final user = userCredential.user;
          if (user == null) {
            throw AuthException('Authentication failed. No user record returned.');
          }
          uid = user.uid;
          phoneNumber = user.phoneNumber;
        }
      } on FirebaseAuthException catch (e) {
        throw AuthException(_mapFirebaseError(e));
      } catch (e) {
        if (e is AuthException) rethrow;
        throw AuthException('Invalid OTP. Please try again.');
      }
    } else {
      // Headless unit test fallback
      if (cleanOtp != AppConstants.devTestOtp && cleanOtp != '999999' && cleanOtp != '123456') {
        throw AuthException('Invalid OTP. Please try again.');
      }
      uid = 'usr_${IdGenerator.generateId()}';
    }

    final cleanedMobile = mobile.replaceAll(RegExp(r'\D'), '');

    // 2. Enforce Flow Integrity Based on UID
    if (!isNewAccount) {
      // LOGIN FLOW: Account must already exist
      final hasProfile = await _cloudSync.hasAccountProfile(uid) || await checkAccountExists(cleanedMobile);
      if (!hasProfile) {
        // Sign out Firebase user session since account setup was never performed
        try {
          await authInstance?.signOut();
        } catch (_) {}
        throw AuthException('Account not found. Please create an account first.');
      }
    } else {
      // CREATE ACCOUNT FLOW: Account must not already exist
      final hasProfile = await _cloudSync.hasAccountProfile(uid) || await checkAccountExists(cleanedMobile);
      if (hasProfile) {
        throw AuthException('An account already exists for this number. Please log in instead.');
      }
    }

    // 3. Establish Session & Cloud Identity
    final resolvedOwner = (ownerName != null && ownerName.isNotEmpty) ? ownerName : 'Store Owner';
    final resolvedBusiness = (businessName != null && businessName.isNotEmpty) ? businessName : 'SCANZO Store';

    final session = UserSession(
      id: uid.isNotEmpty ? uid : IdGenerator.generateId('usr'),
      ownerName: resolvedOwner,
      businessName: resolvedBusiness,
      mobile: phoneNumber ?? cleanedMobile,
      email: email,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Persist session
    await _sessionService.saveSession(session);

    // Register in persistent cloud registry
    if (isNewAccount) {
      await _cloudSync.registerAccount(
        uid: session.id,
        mobile: cleanedMobile,
        ownerName: resolvedOwner,
        businessName: resolvedBusiness,
        email: email,
      );
    }

    // Isolate active database to this Firebase UID and restore existing stores/products
    await DatabaseHelper().setActiveUserId(session.id);

    // If new account, ensure initial business profile is created with this UID
    if (isNewAccount && DatabaseHelper().businessProfile == null) {
      final initialStore = BusinessProfile(
        id: 'store_${DateTime.now().millisecondsSinceEpoch % 10000}',
        userId: session.id,
        businessName: resolvedBusiness,
        ownerName: resolvedOwner,
        mobile: cleanedMobile,
        email: email,
        address: 'Main Store',
        city: 'City',
        state: 'State',
        pincode: '000000',
        shopTypeId: (businessType ?? 'retail').toLowerCase().replaceAll(' ', '_'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await DatabaseHelper().saveBusinessProfile(initialStore);
    }

    return session;
  }

  /// Restores session on app startup by checking Firebase currentUser.
  /// If authenticated, restores the user session and store data.
  /// If not authenticated, clears local session and prompts login.
  Future<bool> restoreSessionOnStartup() async {
    final authInstance = _auth;
    final firebaseUser = authInstance?.currentUser;

    if (firebaseUser != null) {
      final uid = firebaseUser.uid;
      final hasProfile = await _cloudSync.hasAccountProfile(uid);

      if (hasProfile) {
        // Restore existing user profile
        final profile = await _cloudSync.getAccountProfile(uid);
        final session = UserSession(
          id: uid,
          ownerName: profile?['ownerName'] ?? 'Store Owner',
          businessName: profile?['businessName'] ?? 'SCANZO Store',
          mobile: firebaseUser.phoneNumber ?? profile?['mobile'] ?? '',
          email: profile?['email'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _sessionService.saveSession(session);
        await DatabaseHelper().setActiveUserId(uid);
        return true;
      }
    }

    // If not authenticated or profile not found, ensure logged out state
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

  String _mapFirebaseError(dynamic error) {
    String code = '';
    String rawMessage = '';

    if (error is FirebaseAuthException) {
      code = error.code.toLowerCase().trim();
      rawMessage = error.message ?? '';
    } else {
      final str = error.toString().toLowerCase();
      // Extract Firebase code e.g. [firebase_auth/quota-exceeded] or auth/quota-exceeded
      final match = RegExp(r'(?:firebase_auth\/|auth\/)([a-z0-9\-]+)').firstMatch(str);
      if (match != null) {
        code = match.group(1)!;
      }
      rawMessage = error.toString();
    }

    // Strip common technical prefixes e.g. [firebase_auth/quota-exceeded]
    rawMessage = rawMessage
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceFirst(RegExp(r'^(Exception|AuthException|FirebaseAuthException):\s*'), '')
        .trim();

    switch (code) {
      case 'invalid-phone-number':
        return 'Invalid mobile number format. Please enter a valid 10-digit mobile number.';
      case 'too-many-requests':
        return 'Too many SMS requests sent to this number. Please wait a few minutes before trying again.';
      case 'quota-exceeded':
        return 'SMS quota exceeded for this Firebase project. Daily free tier limit reached. Please upgrade to Firebase Blaze (Pay-as-you-go) plan or try again later.';
      case 'billing-not-enabled':
        return 'SMS sending requires Firebase billing enabled. Please upgrade your Firebase project to the Blaze plan in Firebase Console to send SMS to real phone numbers.';
      case 'captcha-check-failed':
        return 'reCAPTCHA verification failed. Please refresh the browser page and ensure cookies/popups are enabled.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection and try again.';
      case 'app-not-authorized':
        return 'This app or domain is not authorized. On Vercel, please add your domain in Firebase Console > Authentication > Settings > Authorized domains.';
      case 'unauthorized-domain':
        return 'Web domain is not authorized. Please add your Vercel deployment domain to Firebase Authentication > Settings > Authorized domains.';
      case 'operation-not-allowed':
        return 'Phone authentication is disabled. Please enable the Phone provider in Firebase Console > Authentication > Sign-in method.';
      case 'invalid-app-credential':
        return 'Phone verification credentials could not be validated. Please complete the reCAPTCHA verification.';
      case 'invalid-verification-code':
        return 'Invalid OTP code. Please check your SMS and enter the correct 6-digit code.';
      case 'session-expired':
        return 'The OTP has expired. Please tap "Resend Code" to request a new OTP.';
      case 'missing-verification-code':
        return 'Please enter the complete 6-digit OTP code.';
      case 'invalid-api-key':
      case 'api-key-not-valid':
        return 'Firebase API key is invalid. Please verify your Firebase project configuration in firebase_options.dart.';
      default:
        if (rawMessage.isNotEmpty &&
            !rawMessage.toLowerCase().contains('instance of') &&
            !rawMessage.toLowerCase().contains('unhandled exception')) {
          return rawMessage;
        }
        return 'Could not send SMS OTP. Please check your mobile number and try again.';
    }
  }
}
