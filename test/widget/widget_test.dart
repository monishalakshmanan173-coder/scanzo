import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanzo/app/app.dart';
import 'package:scanzo/core/constants/app_constants.dart';
import 'package:scanzo/data/database/database_helper.dart';
import 'package:scanzo/data/services/session_service.dart';
import 'package:scanzo/shared/widgets/scanzo_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper().init();
    await SessionService().init();
  });

  testWidgets('ScanzoApp boots up and displays brand name and tagline', (WidgetTester tester) async {
    await tester.pumpWidget(const ScanzoApp());

    // Initially on Splash screen, verify SCANZO branding is rendered
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text(AppConstants.appTagline), findsOneWidget);

    // Advance time past the 1500ms splash navigation timer so no timers are left pending
    await tester.pump(const Duration(milliseconds: 2000));
  });

  testWidgets('ScanzoButton renders text, responds to tap and shows loading indicator', (WidgetTester tester) async {
    bool wasTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ScanzoButton(
              text: 'Click Me',
              onPressed: () => wasTapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Click Me'), findsOneWidget);
    await tester.tap(find.text('Click Me'));
    expect(wasTapped, true);

    // Test loading state
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ScanzoButton(
              text: 'Click Me',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
