import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/id_generator.dart';
import '../../firebase_options.dart';

/// Internal representation of an in-flight OTP session.
class OtpSession {
  final String verificationId;
  final String mobile;
  final String otp;
  final DateTime createdAt;
  DateTime expiresAt;
  DateTime lastSentAt;
  int attempts;
  bool isUsed;

  OtpSession({
    required this.verificationId,
    required this.mobile,
    required this.otp,
    required this.createdAt,
    required this.expiresAt,
    required this.lastSentAt,
    this.attempts = 0,
    this.isUsed = false,
  });
}

/// Service managing the complete OTP pipeline:
/// Phone normalization -> Rate limiting & Cooldown -> Dynamic cryptographic OTP generation
/// -> Multi-provider SMS dispatch (Firebase Phone Auth / External SMS API Gateway)
/// -> Strict 6-digit session verification & security.
class OtpService {
  static final OtpService _instance = OtpService._internal();
  factory OtpService({FirebaseAuth? firebaseAuth, http.Client? httpClient}) {
    if (firebaseAuth != null) _instance._firebaseAuth = firebaseAuth;
    if (httpClient != null) _instance._httpClient = httpClient;
    return _instance;
  }
  OtpService._internal();

  FirebaseAuth? _firebaseAuth;
  http.Client? _httpClient;

  http.Client get _http => _httpClient ?? http.Client();

  FirebaseAuth? get _auth {
    if (_firebaseAuth != null) return _firebaseAuth;
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance;
      }
    } catch (_) {}
    return null;
  }

  // Active in-memory OTP verification sessions
  final Map<String, OtpSession> _sessions = {};
  ConfirmationResult? _webConfirmationResult;

  /// Explicit flag to allow test mocking during automated test runs
  static bool isTestMode = false;

  /// Returns true if currently running in an automated test environment
  bool get isInTestEnvironment => isTestMode || (kDebugMode && !kIsWeb && Firebase.apps.isEmpty);

  /// Check whether real (non-placeholder) Firebase credentials are configured
  bool get isFirebaseConfigured {
    try {
      final key = DefaultFirebaseOptions.currentPlatform.apiKey;
      return key.isNotEmpty && !key.toLowerCase().contains('placeholder');
    } catch (_) {
      return false;
    }
  }

  /// Check whether external SMS provider credentials are provided
  bool get isExternalSmsConfigured {
    const smsApiKey = String.fromEnvironment('SMS_API_KEY', defaultValue: '');
    const smsGatewayUrl = String.fromEnvironment('SMS_GATEWAY_URL', defaultValue: '');
    return smsApiKey.isNotEmpty || smsGatewayUrl.isNotEmpty;
  }

  /// Masks mobile number for safe production debug logging
  static String maskMobile(String mobile) {
    String clean = mobile.replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('91') && clean.length == 12) {
      clean = clean.substring(2);
    } else if (clean.startsWith('0') && clean.length == 11) {
      clean = clean.substring(1);
    }
    if (clean.length == 10) {
      return '+91 ******${clean.substring(6)}';
    } else if (clean.length > 4) {
      return '******${clean.substring(clean.length - 4)}';
    }
    return '***';
  }

  /// Masks verification ID for safe production debug logging
  static String maskVerId(String id) {
    if (id.length > 8) {
      return '${id.substring(0, 8)}...';
    }
    return id;
  }

  /// Normalizes phone number to clean 10-digit format
  String normalizeMobile(String mobile) {
    String cleaned = mobile.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  /// Dispatches an OTP to the given 10-digit mobile number.
  /// Enforces rate limiting cooldown, generates dynamic 6-digit code, and dispatches via SMS.
  Future<String> sendOtp({
    required String mobile,
    bool forceResend = false,
    void Function(String verificationId)? onCodeSent,
    void Function(String error)? onError,
  }) async {
    final clean = normalizeMobile(mobile);
    if (clean.length != 10) {
      throw ValidationException('Please enter a valid 10-digit mobile number.');
    }

    // 1. Enforce 30-second cooldown rate limit for repeated requests to this number
    final existingSession = _findLatestSessionForMobile(clean);
    if (existingSession != null && !existingSession.isUsed && !forceResend) {
      final elapsedSeconds = DateTime.now().difference(existingSession.lastSentAt).inSeconds;
      if (elapsedSeconds < 30) {
        throw AuthException('Too many attempts. Please wait and try again.');
      }
    }

    // 2. Generate a cryptographically secure dynamic 6-digit OTP
    final random = Random.secure();
    final dynamicOtp = (100000 + random.nextInt(900000)).toString();
    final verificationId = 'scz_ver_${DateTime.now().millisecondsSinceEpoch}_${IdGenerator.generateId()}';

    // 3. Store active verification session (5 minutes expiry)
    final now = DateTime.now();
    _sessions[verificationId] = OtpSession(
      verificationId: verificationId,
      mobile: clean,
      otp: dynamicOtp,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
      lastSentAt: now,
    );

    // Invalidate previous in-flight sessions for this number
    if (existingSession != null && existingSession.verificationId != verificationId) {
      existingSession.isUsed = true;
    }

    // 4. SMS Dispatch Pipeline
    final formattedNumber = '+91$clean';
    final authInstance = _auth;

    // A. If real Firebase configuration is detected, attempt Firebase Phone Auth
    if (isFirebaseConfigured && authInstance != null) {
      try {
        if (kIsWeb) {
          debugPrint('[OTP Provider] Dispatching via Firebase Web Phone Auth to ${maskMobile(clean)}...');
          final confirmationResult = await authInstance.signInWithPhoneNumber(formattedNumber);
          _webConfirmationResult = confirmationResult;
          final fbVerId = confirmationResult.verificationId;
          debugPrint('[OTP Provider] Firebase Web Phone Auth: dispatch confirmed. Verification ID: ${maskVerId(fbVerId)}');
          onCodeSent?.call(fbVerId);
          return fbVerId;
        } else {
          final completer = Completer<String>();
          debugPrint('[OTP Provider] Dispatching via Firebase Mobile Phone Auth to ${maskMobile(clean)}...');
          await authInstance.verifyPhoneNumber(
            phoneNumber: formattedNumber,
            timeout: const Duration(seconds: 60),
            verificationCompleted: (_) {
              debugPrint('[OTP Provider] Firebase auto-verification completed.');
            },
            verificationFailed: (FirebaseAuthException e) {
              debugPrint('[OTP Provider] Firebase Mobile Phone Auth failed: code=${e.code}');
              final mapped = mapAuthError(e);
              onError?.call(mapped);
              if (!completer.isCompleted) completer.completeError(AuthException(mapped));
            },
            codeSent: (String vid, int? token) {
              debugPrint('[OTP Provider] Firebase Mobile Phone Auth: code sent. Verification ID: ${maskVerId(vid)}');
              onCodeSent?.call(vid);
              if (!completer.isCompleted) completer.complete(vid);
            },
            codeAutoRetrievalTimeout: (String vid) {
              debugPrint('[OTP Provider] Firebase code auto retrieval timeout.');
              if (!completer.isCompleted) completer.complete(vid);
            },
          );
          return await completer.future.timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              debugPrint('[OTP Provider] Firebase Phone Auth timed out waiting for codeSent.');
              throw AuthException('OTP dispatch timed out. Please try again.');
            },
          );
        }
      } catch (e) {
        if (e is AuthException) rethrow;
        final mapped = mapAuthError(e);
        onError?.call(mapped);
        throw AuthException(mapped);
      }
    }

    // B. Check for external SMS Provider (Fast2SMS / 2Factor / Twilio / Custom API Gateway)
    if (isExternalSmsConfigured) {
      final smsProvider = const String.fromEnvironment('SMS_PROVIDER', defaultValue: '').toLowerCase();
      const smsApiKey = String.fromEnvironment('SMS_API_KEY', defaultValue: '');
      const smsGatewayUrl = String.fromEnvironment('SMS_GATEWAY_URL', defaultValue: '');

      try {
        debugPrint('[OTP Provider] Dispatching via external SMS gateway ($smsProvider) to ${maskMobile(clean)}...');
        await _dispatchExternalSms(
          provider: smsProvider,
          apiKey: smsApiKey,
          gatewayUrl: smsGatewayUrl,
          mobile: clean,
          otp: dynamicOtp,
        );
        debugPrint('[OTP Provider] External SMS gateway dispatch confirmed.');
        onCodeSent?.call(verificationId);
        return verificationId;
      } catch (e) {
        if (e is AuthException) rethrow;
        throw AuthException('Unable to send OTP. Please try again.');
      }
    }

    // C. Check for Test / Mock Environment (Unit & Widget Tests Only)
    if (isInTestEnvironment) {
      debugPrint('[OTP Provider] Test environment active: simulated OTP dispatch confirmed.');
      onCodeSent?.call(verificationId);
      return verificationId;
    }

    // D. Production without configured provider -> Strict Failure (Never fake OTP dispatch!)
    debugPrint('[OTP Provider] CRITICAL: No active SMS provider is configured for production.');
    debugPrint('[OTP Provider] Firebase credentials are placeholder or missing (check FIREBASE_WEB_API_KEY).');
    debugPrint('[OTP Provider] External SMS gateway is unconfigured (check SMS_API_KEY / SMS_GATEWAY_URL).');
    throw AuthException('Unable to send OTP. SMS service is not configured. Please check deployment settings.');
  }

  /// Dispatches SMS via configured external SMS Gateway HTTP Provider
  Future<void> _dispatchExternalSms({
    required String provider,
    required String apiKey,
    required String gatewayUrl,
    required String mobile,
    required String otp,
  }) async {
    try {
      if (provider == 'fast2sms') {
        // Fast2SMS Quick SMS OTP API
        final uri = Uri.parse('https://www.fast2sms.com/dev/bulkV2');
        final response = await _http.post(
          uri,
          headers: {
            'authorization': apiKey,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'route': 'otp',
            'variables_values': otp,
            'numbers': mobile,
          },
        ).timeout(const Duration(seconds: 15));

        debugPrint('[OTP Provider] Fast2SMS response status: ${response.statusCode}');
        if (response.statusCode == 429) {
          throw AuthException('Too many attempts. Please wait and try again.');
        }
        if (response.statusCode != 200) {
          throw AuthException('Unable to send OTP. Please try again.');
        }
      } else if (provider == '2factor') {
        // 2Factor.in SMS OTP API
        final uri = Uri.parse('https://2factor.in/API/V1/$apiKey/SMS/+91$mobile/$otp/ScanzoBilling');
        final response = await _http.get(uri).timeout(const Duration(seconds: 15));

        debugPrint('[OTP Provider] 2Factor response status: ${response.statusCode}');
        if (response.statusCode == 429) {
          throw AuthException('Too many attempts. Please wait and try again.');
        }
        if (response.statusCode != 200) {
          throw AuthException('Unable to send OTP. Please try again.');
        }
      } else if (provider == 'twilio') {
        const accountSid = String.fromEnvironment('TWILIO_ACCOUNT_SID', defaultValue: '');
        const authToken = String.fromEnvironment('TWILIO_AUTH_TOKEN', defaultValue: '');
        const fromNumber = String.fromEnvironment('TWILIO_FROM_NUMBER', defaultValue: '');

        if (accountSid.isNotEmpty && authToken.isNotEmpty) {
          final uri = Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');
          final basicAuth = 'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}';
          final response = await _http.post(
            uri,
            headers: {'Authorization': basicAuth},
            body: {
              'To': '+91$mobile',
              'From': fromNumber,
              'Body': 'Your SCANZO verification code is: $otp. Valid for 5 minutes.',
            },
          ).timeout(const Duration(seconds: 15));

          debugPrint('[OTP Provider] Twilio response status: ${response.statusCode}');
          if (response.statusCode == 429) {
            throw AuthException('Too many attempts. Please wait and try again.');
          }
          if (response.statusCode != 200 && response.statusCode != 201) {
            throw AuthException('Unable to send OTP. Please try again.');
          }
        }
      } else if (gatewayUrl.isNotEmpty) {
        // Custom backend or enterprise SMS gateway
        final uri = Uri.parse(gatewayUrl);
        final headers = {
          'Content-Type': 'application/json',
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        };
        final body = jsonEncode({
          'mobile': '+91$mobile',
          'otp': otp,
          'app': 'SCANZO',
        });
        final response = await _http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 15));

        debugPrint('[OTP Provider] Custom gateway response status: ${response.statusCode}');
        if (response.statusCode == 429) {
          throw AuthException('Too many attempts. Please wait and try again.');
        }
        if (response.statusCode != 200 && response.statusCode != 201) {
          throw AuthException('Unable to send OTP. Please try again.');
        }
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('[OTP Provider] External SMS dispatch error: $e');
      throw AuthException('Unable to send OTP. Please try again.');
    }
  }

  /// Verifies the entered 6-digit OTP code against the active verification session.
  /// Throws standard user-friendly AuthExceptions on invalid, expired, or throttled attempts.
  Future<bool> verifyOtp({
    required String mobile,
    required String otp,
    String? verificationId,
  }) async {
    final cleanOtp = otp.trim();
    if (cleanOtp.length != 6 || int.tryParse(cleanOtp) == null) {
      throw ValidationException('Please enter the complete 6-digit OTP.');
    }

    final cleanMobile = normalizeMobile(mobile);

    // 1. If Firebase Web Phone Auth confirmation result is active
    if (_webConfirmationResult != null && isFirebaseConfigured) {
      try {
        debugPrint('[OTP Provider] Verifying code with Firebase Web confirmation result...');
        final cred = await _webConfirmationResult!.confirm(cleanOtp);
        if (cred.user != null) {
          debugPrint('[OTP Provider] Firebase Web Phone Auth verification succeeded.');
          _webConfirmationResult = null;
          return true;
        }
      } on FirebaseAuthException catch (e) {
        debugPrint('[OTP Provider] Firebase Web verify error: code=${e.code}');
        throw AuthException(mapAuthError(e));
      } catch (e) {
        debugPrint('[OTP Provider] Firebase Web verify unexpected error: $e');
        throw AuthException('Invalid OTP. Please check the code and try again.');
      }
    }

    // 2. If Firebase Mobile Phone Auth credential verification
    final authInstance = _auth;
    if (verificationId != null &&
        !verificationId.startsWith('scz_ver_') &&
        isFirebaseConfigured &&
        authInstance != null &&
        !kIsWeb) {
      try {
        debugPrint('[OTP Provider] Verifying code with Firebase Mobile PhoneAuthCredential...');
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: cleanOtp,
        );
        final userCred = await authInstance.signInWithCredential(credential);
        if (userCred.user != null) {
          debugPrint('[OTP Provider] Firebase Mobile Phone Auth verification succeeded.');
          return true;
        }
      } on FirebaseAuthException catch (e) {
        debugPrint('[OTP Provider] Firebase Mobile verify error: code=${e.code}');
        throw AuthException(mapAuthError(e));
      } catch (e) {
        debugPrint('[OTP Provider] Firebase Mobile verify unexpected error: $e');
        throw AuthException('Invalid OTP. Please check the code and try again.');
      }
    }

    // 3. Validate against local in-memory dynamic session engine (for External SMS Gateway & Tests)
    OtpSession? session;
    if (verificationId != null && _sessions.containsKey(verificationId)) {
      session = _sessions[verificationId];
    } else {
      session = _findLatestSessionForMobile(cleanMobile);
    }

    if (session == null || session.isUsed) {
      throw AuthException('OTP expired. Please request a new OTP.');
    }

    // Check expiration (5 minutes)
    if (DateTime.now().isAfter(session.expiresAt)) {
      _sessions.remove(session.verificationId);
      throw AuthException('OTP expired. Please request a new OTP.');
    }

    // Check max attempts (5 attempts limit)
    if (session.attempts >= 5) {
      _sessions.remove(session.verificationId);
      throw AuthException('Too many attempts. Please wait and try again.');
    }

    // Strict dynamic OTP match
    if (session.otp != cleanOtp) {
      session.attempts++;
      throw AuthException('Invalid OTP. Please check the code and try again.');
    }

    // Success: mark session used and clear
    session.isUsed = true;
    _sessions.remove(session.verificationId);
    return true;
  }

  OtpSession? _findLatestSessionForMobile(String cleanMobile) {
    OtpSession? latest;
    for (var s in _sessions.values) {
      if (s.mobile == cleanMobile && !s.isUsed) {
        if (latest == null || s.createdAt.isAfter(latest.createdAt)) {
          latest = s;
        }
      }
    }
    return latest;
  }

  /// Maps any Firebase or infrastructure error code into user-friendly requirement errors with safe diagnostics.
  String mapAuthError(dynamic error) {
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
        debugPrint('[OTP Provider] Diagnostics: Invalid phone number format.');
        return 'Please enter a valid 10-digit mobile number.';
      case 'too-many-requests':
        debugPrint('[OTP Provider] Diagnostics: Throttled by provider due to too many requests.');
        return 'Too many attempts. Please wait and try again.';
      case 'invalid-verification-code':
        debugPrint('[OTP Provider] Diagnostics: Verification code mismatch.');
        return 'Invalid OTP. Please check the code and try again.';
      case 'session-expired':
        debugPrint('[OTP Provider] Diagnostics: Verification session expired.');
        return 'OTP expired. Please request a new OTP.';
      case 'network-request-failed':
        debugPrint('[OTP Provider] Diagnostics: Network connectivity failure.');
        return 'Network error. Please check your internet connection and try again.';
      case 'unauthorized-domain':
        debugPrint('[OTP Provider] Diagnostics: Hosting domain unauthorized in Firebase Console > Authentication > Settings > Authorized Domains.');
        return 'Deployment domain is not authorized for SMS verification. Please contact support.';
      case 'quota-exceeded':
      case 'billing-not-enabled':
        debugPrint('[OTP Provider] Diagnostics: SMS daily quota exceeded or billing not enabled in Firebase.');
        return 'SMS quota reached for today. Please try again later or contact support.';
      case 'operation-not-allowed':
        debugPrint('[OTP Provider] Diagnostics: Phone sign-in is disabled in Firebase Console.');
        return 'Phone sign-in is disabled. Please contact support.';
      case 'captcha-check-failed':
        debugPrint('[OTP Provider] Diagnostics: reCAPTCHA verification failed or cancelled by user.');
        return 'Verification check failed. Please refresh and try again.';
      case 'invalid-app-credential':
      case 'missing-app-credential':
        debugPrint('[OTP Provider] Diagnostics: App credential / reCAPTCHA token missing or expired.');
        return 'Verification check failed. Please refresh and try again.';
      case 'invalid-api-key':
      case 'api-key-not-valid':
        debugPrint('[OTP Provider] Diagnostics: Firebase Web API key is invalid.');
        return 'Authentication configuration error. Please contact support.';
      default:
        debugPrint('[OTP Provider] Diagnostics: Provider error code: $code');
        return 'Unable to send OTP. Please try again.';
    }
  }

  // --- Methods for Automated Testing Only ---

  @visibleForTesting
  String? getGeneratedOtpForTesting(String verificationId) {
    return _sessions[verificationId]?.otp;
  }

  @visibleForTesting
  void expireSessionForTesting(String verificationId) {
    final s = _sessions[verificationId];
    if (s != null) {
      s.expiresAt = DateTime.now().subtract(const Duration(seconds: 10));
    }
  }

  @visibleForTesting
  void clearSessionsForTesting() {
    _sessions.clear();
    _webConfirmationResult = null;
  }
}
