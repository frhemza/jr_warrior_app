import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jr_warrior_app/screens/login_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Login screen switches between Sign In and Create Account', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('Jr. Warrior'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.text('Coach'), findsNothing);
    expect(find.text('Parent'), findsNothing);
    expect(find.text('Sign In'), findsWidgets);

    await tester.tap(find.text('Need an account? Create Account'));
    await tester.pump();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Coach'), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Full name'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Phone'), findsOneWidget);
    expect(find.text('Create Account'), findsWidgets);
  });
}
