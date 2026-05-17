import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:property_manager/screens/login_screen.dart';

void main() {
  testWidgets('login screen renders primary actions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('Property Manager'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);

    expect(find.byIcon(Icons.home_work_rounded), findsOneWidget);
  });
}
