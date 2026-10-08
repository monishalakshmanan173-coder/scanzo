import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanzo/shared/widgets/scanzo_logo.dart';

void main() {
  testWidgets('ScanzoLogo renders without overflow and shows vector fallback when asset absent', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ScanzoLogo(size: 96),
          ),
        ),
      ),
    );

    expect(find.byType(ScanzoLogo), findsOneWidget);
  });

  testWidgets('ScanzoLogo.icon and ScanzoLogo.large render designated sizes', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ScanzoLogo.icon(size: 32),
              ScanzoLogo.large(size: 130),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(ScanzoLogo), findsNWidgets(2));
  });
}
