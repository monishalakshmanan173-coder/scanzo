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

  /// Check whether real (non-placeholder) Firebase credentials are provided
  bool get isFirebaseConfigured {
    try {
      final key = DefaultFirebaseOptions.currentPlatform.apiKey;
      return key.isNotEmpty && !key.toLowerCase().contains('placeholder');
    } catch (_) {
      return false;
    }
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
    if (existingSession != null && !existingSession.isUsed) {
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
          final confirmationResult = await authInstance.signInWithPhoneNumber(formattedNumber);
          _webConfirmationResult = confirmationResult;
          final fbVerId = confirmationResult.verificationId;
          onCodeSent?.call(fbVerId);
          return fbVerId;
        } else {
          final completer = Completer<String>();
          await authInstance.verifyPhoneNumber(
            phoneNumber: formattedNumber,
            timeout: const Duration(seconds: 60),
            verificationCompleted: (_) {},
            verificationFailed: (FirebaseAuthException e) {
              final mapped = mapAuthError(e);
              onError?.call(mapped);
              if (!completer.isCompleted) completer.completeError(AuthException(mapped));
            },
            codeSent: (String vid, int? token) {
              onCodeSent?.call(vid);
              if (!completer.isCompleted) completer.complete(vid);
            },
            codeAutoRetrievalTimeout: (String vid) {
              if (!completer.isCompleted) completer.complete(vid);
            },
          );
          return await completer.future.timeout(
            const Duration(seconds: 45),
            onTimeout: () => verificationId,
          );
        }
      } catch (e) {
        if (e is AuthException) rethrow;
        throw AuthException(mapAuthError(e));
      }
    }

    // B. Check for external SMS Provider (Fast2SMS / 2Factor / Twilio / Custom API Gateway)
    final smsProvider = const String.fromEnvironment('SMS_PROVIDER', defaultValue: '').toLowerCase();
    const smsApiKey = String.fromEnvironment('SMS_API_KEY', defaultValue: '');
    const smsGatewayUrl = String.fromEnvironment('SMS_GATEWAY_URL', defaultValue: '');

    if (smsApiKey.isNotEmpty || smsGatewayUrl.isNotEmpty) {
      try {
        await _dispatchExternalSms(
          provider: smsProvider,
          apiKey: smsApiKey,
          gatewayUrl: smsGatewayUrl,
          mobile: clean,
          otp: dynamicOtp,
        );
      } catch (e) {
        if (e is AuthException) rethrow;
        throw AuthException('Unable to send OTP. Please try again.');
      }
    }

    onCodeSent?.call(verificationId);
    return verificationId;
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

        if (response.statusCode == 429) {
          throw AuthException('Too many attempts. Please wait and try again.');
        }
        if (response.statusCode != 200 && response.statusCode != 201) {
          throw AuthException('Unable to send OTP. Please try again.');
        }
      }
    } catch (e) {
      if (e is AuthException) rethrow;
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

    // 1. If Firebase Phone Auth confirmation result is active
    if (_webConfirmationResult != null && isFirebaseConfigured) {
      try {
        final cred = await _webConfirmationResult!.confirm(cleanOtp);
        if (cred.user != null) {
          _webConfirmationResult = null;
          return true;
        }
      } on FirebaseAuthException catch (e) {
        throw AuthException(mapAuthError(e));
      } catch (e) {
        throw AuthException('Invalid OTP. Please check the code and try again.');
      }
    }

    // 2. Validate against session engine
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

  /// Maps any Firebase or infrastructure error code into the user-friendly requirement errors.
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
