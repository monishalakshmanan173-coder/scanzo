import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanzo/features/auth/screens/login_screen.dart';
import 'package:scanzo/features/auth/screens/create_account_screen.dart';
import 'package:scanzo/features/auth/screens/otp_screen.dart';
import 'package:scanzo/data/services/session_service.dart';
import 'package:scanzo/data/services/cloud_sync_service.dart';
import 'package:scanzo/data/services/otp_service.dart';
import 'package:scanzo/data/repositories/auth_repository.dart';
import 'package:scanzo/data/database/database_helper.dart';
import 'package:scanzo/app/routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionService().logout();
    await SessionService().init();
    await DatabaseHelper().init();
    OtpService().clearSessionsForTesting();
  });

  testWidgets('CASE 1 Widget: Login with unregistered number shows "Account not found" and remains on screen', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.login: (_) => const LoginScreen(),
          AppRoutes.createAccount: (_) => const CreateAccountScreen(),
          AppRoutes.otp: (ctx) => OtpScreen(
                arguments: ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>,
              ),
        },
        initialRoute: AppRoutes.login,
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    // 1. Enter unregistered 10-digit number
    final mobileFinder = find.byType(TextFormField);
    expect(mobileFinder, findsOneWidget);
    await tester.enterText(mobileFinder, '9876543210');
    await tester.pump(const Duration(milliseconds: 100));

    // 2. Tap Send OTP
    final sendOtpButton = find.widgetWithText(ElevatedButton, 'Send OTP');
    expect(sendOtpButton, findsOneWidget);
    await tester.tap(sendOtpButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 3. Verify: Shows "Account not found. Please create an account first."
    expect(find.text('Account not found. Please create an account first.'), findsOneWidget);

    // 4. Verify: Shows "Create Account Now" button
    expect(find.text('Create Account Now'), findsOneWidget);

    // 5. Verify: Remained on LoginScreen, did NOT navigate to OTP screen
    expect(find.text('Login to Your Account'), findsOneWidget);
    expect(find.text('Enter Verification Code'), findsNothing);
  });

  testWidgets('CASE 2 Widget: Login with registered number navigates to OTP screen', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Register the user in CloudSyncService
    await CloudSyncService().registerAccount(
      uid: 'test_registered_user',
      mobile: '9876543210',
      ownerName: 'Vikas Gupta',
      businessName: 'Gupta Traders',
    );

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.login: (_) => const LoginScreen(),
          AppRoutes.otp: (ctx) => OtpScreen(
                arguments: ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>,
              ),
        },
        initialRoute: AppRoutes.login,
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    // Enter registered mobile
    final mobileFinder = find.byType(TextFormField);
    await tester.enterText(mobileFinder, '9876543210');
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Send OTP
    final sendOtpButton = find.widgetWithText(ElevatedButton, 'Send OTP');
    await tester.tap(sendOtpButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 400));

    // Verify: Successfully navigated to OTP screen
    expect(find.text('Enter Verification Code'), findsOneWidget);
    expect(find.text('Sent 6-digit code to +91 9876543210'), findsOneWidget);
  });

  testWidgets('CASE 3 Widget: Create account with existing number shows "already exists" error', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Pre-register user
    await CloudSyncService().registerAccount(
      uid: 'existing_user_1',
      mobile: '9123456780',
      ownerName: 'Sunita Rao',
      businessName: 'Rao Sweets',
    );

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.createAccount: (_) => const CreateAccountScreen(),
          AppRoutes.login: (_) => const LoginScreen(),
        },
        initialRoute: AppRoutes.createAccount,
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    // Fill form
    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(4)); // Owner Name, Business Name, Mobile, Email

    await tester.enterText(textFields.at(0), 'Sunita Rao');
    await tester.enterText(textFields.at(1), 'Rao Sweets');
    await tester.enterText(textFields.at(2), '9123456780'); // already exists
    await tester.pump(const Duration(milliseconds: 100));

    // Tap Create Account
    final createBtn = find.widgetWithText(ElevatedButton, 'Create Account');
    await tester.ensureVisible(createBtn);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(createBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify error
    expect(
      find.text('An account already exists for this number. Please log in instead.'),
      findsOneWidget,
    );
    expect(find.text('Log In to Existing Account'), findsOneWidget);
  });

  testWidgets('CASE 4 Widget: Wrong OTP on OtpScreen displays "Invalid OTP" error', (tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final authRepo = AuthRepository();
    // Dispatch OTP
    final verId = await authRepo.sendOtp('9876543210', isNewAccount: true);
    final realOtp = authRepo.otpService.getGeneratedOtpForTesting(verId)!;
    final wrongOtp = realOtp == '111111' ? '222222' : '111111';

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.otp: (_) => OtpScreen(
                arguments: {
                  'mobile': '9876543210',
                  'verificationId': verId,
                  'isNewAccount': true,
                },
              ),
          AppRoutes.dashboard: (_) => const Scaffold(body: Text('Dashboard View')),
        },
        initialRoute: AppRoutes.otp,
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    // Enter wrong 6 digits
    final otpBoxes = find.byType(TextFormField);
    expect(otpBoxes, findsNWidgets(6));

    final wrongDigits = wrongOtp.split('');
    for (int i = 0; i < 5; i++) {
      await tester.enterText(otpBoxes.at(i), wrongDigits[i]);
      await tester.pump(const Duration(milliseconds: 50));
    }
    // Enter 6th digit
    await tester.enterText(otpBoxes.at(5), wrongDigits[5]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify error displayed
    expect(
      find.text('Invalid OTP. Please check the code and try again.'),
      findsOneWidget,
    );
    // Did not navigate to dashboard
    expect(find.text('Dashboard View'), findsNothing);
  });
}
