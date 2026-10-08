import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanzo/core/constants/app_constants.dart';
import 'package:scanzo/core/errors/app_exceptions.dart';
import 'package:scanzo/data/services/session_service.dart';
import 'package:scanzo/data/repositories/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthRepository and Session Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Send OTP validates 10-digit mobile number', () async {
      final authRepo = AuthRepository();

      // Invalid mobile numbers should throw ValidationException
      expect(
        () => authRepo.sendOtp('123'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => authRepo.sendOtp('abcdefghij'),
        throwsA(isA<ValidationException>()),
      );

      // Valid 10-digit mobile number should succeed
      await expectLater(authRepo.sendOtp('9876543210'), completes);
    });

    test('Verify OTP with devTestOtp succeeds and persists session', () async {
      final sessionService = SessionService();
      await sessionService.init();
      final authRepo = AuthRepository(sessionService: sessionService);

      expect(authRepo.isLoggedIn, false);

      final user = await authRepo.verifyOtpAndLogin(
        mobile: '9876543210',
        otp: AppConstants.devTestOtp,
        ownerName: 'Test Owner',
        businessName: 'Test Shop',
      );

      expect(user.mobile, '9876543210');
      expect(user.ownerName, 'Test Owner');
      expect(user.businessName, 'Test Shop');
      expect(authRepo.isLoggedIn, true);

      // Verify session survives re-initialization
      final newSessionService = SessionService();
      await newSessionService.init();
      expect(newSessionService.isLoggedIn, true);
      expect(newSessionService.currentUser?.ownerName, 'Test Owner');
    });

    test('Verify OTP with invalid code throws AuthException', () async {
      final authRepo = AuthRepository();

      expect(
        () => authRepo.verifyOtpAndLogin(mobile: '9876543210', otp: '000000'),
        throwsA(isA<AuthException>()),
      );
    });

    test('Logout clears session but keeps onboarding status', () async {
      final sessionService = SessionService();
      await sessionService.init();
      final authRepo = AuthRepository(sessionService: sessionService);

      await authRepo.verifyOtpAndLogin(
        mobile: '9876543210',
        otp: AppConstants.devTestOtp,
      );
      await authRepo.completeOnboarding();
      expect(authRepo.isLoggedIn, true);
      expect(authRepo.isOnboardingDone, true);

      // Perform Logout
      await authRepo.logout();

      expect(authRepo.isLoggedIn, false);
      expect(authRepo.currentUser, isNull);
      // Onboarding state must persist so returning user does not see onboarding again
      expect(authRepo.isOnboardingDone, true);
    });
  });
}
