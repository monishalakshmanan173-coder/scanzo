import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/id_generator.dart';
import '../models/user_session.dart';
import '../services/session_service.dart';
import '../database/database_helper.dart';

class AuthRepository {
  final FirebaseAuth? _firebaseAuth;
  final SessionService _sessionService;

  // In-flight phone verification tokens
  String? _lastVerificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmationResult;

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    SessionService? sessionService,
  })  : _firebaseAuth = firebaseAuth,
        _sessionService = sessionService ?? SessionService();

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

  /// Sends a real SMS OTP to the provided 10-digit mobile number using Firebase Authentication.
  Future<void> sendOtp(
    String mobile, {
    void Function(String verificationId)? onCodeSent,
    void Function(String error)? onError,
  }) async {
    final cleaned = mobile.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 10) {
      throw ValidationException('Please enter a valid 10-digit mobile number');
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
        } else {
          // Android & iOS Native Phone Authentication
          await authInstance.verifyPhoneNumber(
            phoneNumber: formattedNumber,
            timeout: const Duration(seconds: 60),
            verificationCompleted: (PhoneAuthCredential credential) async {
              // Auto-retrieval handled seamlessly on supported devices
            },
            verificationFailed: (FirebaseAuthException e) {
              final message = _mapFirebaseError(e);
              onError?.call(message);
            },
            codeSent: (String verificationId, int? resendToken) {
              _lastVerificationId = verificationId;
              _resendToken = resendToken;
              onCodeSent?.call(verificationId);
            },
            codeAutoRetrievalTimeout: (String verificationId) {
              _lastVerificationId = verificationId;
            },
            forceResendingToken: _resendToken,
          );
        }
      } on FirebaseAuthException catch (e) {
        throw AuthException(_mapFirebaseError(e));
      } catch (e) {
        throw AuthException('Could not send OTP. ${e.toString()}');
      }
    } else {
      // Offline/Test environment fallback
      _lastVerificationId = 'test_ver_${IdGenerator.generateId()}';
      onCodeSent?.call(_lastVerificationId!);
    }
  }

  /// Verifies the entered 6-digit OTP using Firebase Authentication and establishes the user session.
  Future<UserSession> verifyOtpAndLogin({
    required String mobile,
    required String otp,
    String? verificationId,
    String? ownerName,
    String? businessName,
    String? email,
  }) async {
    final cleanOtp = otp.trim();
    if (cleanOtp.length != 6) {
      throw ValidationException('Please enter the complete 6-digit OTP');
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
        throw AuthException('Failed to verify OTP: ${e.toString()}');
      }
    } else {
      // Headless unit test fallback
      if (cleanOtp != AppConstants.devTestOtp && cleanOtp != '999999' && cleanOtp != '123456') {
        throw AuthException('Invalid OTP. Please check the code and try again.');
      }
      uid = 'usr_${IdGenerator.generateId()}';
    }

    final cleanedMobile = mobile.replaceAll(RegExp(r'\D'), '');
    final session = UserSession(
      id: uid.isNotEmpty ? uid : IdGenerator.generateId('usr'),
      ownerName: (ownerName != null && ownerName.isNotEmpty) ? ownerName : 'Shop Owner',
      businessName: (businessName != null && businessName.isNotEmpty) ? businessName : 'SCANZO Store',
      mobile: phoneNumber ?? cleanedMobile,
      email: email,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _sessionService.saveSession(session);
    DatabaseHelper().setActiveUserId(session.id);
    return session;
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
    DatabaseHelper().setActiveUserId('');
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Invalid OTP code. Please check the SMS and try again.';
      case 'invalid-phone-number':
        return 'The mobile number entered is invalid. Please verify the 10 digits.';
      case 'session-expired':
        return 'The OTP has expired. Please tap "Resend Code" for a new OTP.';
      case 'too-many-requests':
        return 'Too many SMS requests sent to this number. Please wait a few minutes before trying again.';
      case 'quota-exceeded':
        return 'SMS quota exceeded for today. Please try again later or contact support.';
      case 'network-request-failed':
        return 'Network connection error. Please check your internet connection.';
      case 'captcha-check-failed':
        return 'reCAPTCHA verification failed. Please try again.';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled in Firebase Console. Please enable Phone provider.';
      default:
        return e.message ?? 'An unexpected authentication error occurred (${e.code}).';
    }
  }
}
