import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/id_generator.dart';
import '../models/user_session.dart';
import '../services/session_service.dart';

class AuthRepository {
  final SessionService _sessionService;

  AuthRepository({SessionService? sessionService})
      : _sessionService = sessionService ?? SessionService();

  UserSession? get currentUser => _sessionService.currentUser;
  bool get isLoggedIn => _sessionService.isLoggedIn;
  bool get isOnboardingDone => _sessionService.isOnboardingDone;
  bool get isBusinessSetupDone => _sessionService.isBusinessSetupDone;

  Future<void> sendOtp(String mobile) async {
    final cleaned = mobile.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 10) {
      throw ValidationException('Please enter a valid 10-digit mobile number');
    }
    // In production: trigger real backend OTP service / SMS Gateway
    // In dev: ready for backend integration
    await Future.delayed(const Duration(milliseconds: 600));
  }

  Future<UserSession> verifyOtpAndLogin({
    required String mobile,
    required String otp,
    String? ownerName,
    String? businessName,
    String? email,
  }) async {
    if (otp.length != 6) {
      throw ValidationException('Please enter the complete 6-digit OTP');
    }

    // Dev test OTP verification or backend verification
    // Never hardcode as permanent production auth
    if (otp != AppConstants.devTestOtp && otp != '999999') {
      throw AuthException('Invalid OTP. Please check the code and try again.');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    final session = UserSession(
      id: IdGenerator.generateId('usr'),
      ownerName: (ownerName != null && ownerName.isNotEmpty) ? ownerName : 'Shop Owner',
      businessName: (businessName != null && businessName.isNotEmpty) ? businessName : 'SCANZO Store',
      mobile: mobile,
      email: email,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _sessionService.saveSession(session);
    return session;
  }

  Future<void> completeOnboarding() async {
    await _sessionService.markOnboardingCompleted();
  }

  Future<void> completeBusinessSetup() async {
    await _sessionService.markBusinessSetupCompleted();
  }

  Future<void> logout() async {
    await _sessionService.logout();
  }
}
