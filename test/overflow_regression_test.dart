import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_up/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:quest_up/features/auth/presentation/screens/login_screen.dart';
import 'package:quest_up/features/auth/presentation/screens/register_screen.dart';
import 'package:quest_up/features/auth/presentation/widgets/forgot_password_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Layout & Overflow Regression Tests (Compact Screen: 360x640 & 320x480)', () {
    testWidgets('OTP Verification Screen test chip and elements do not overflow on 360px width',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OtpVerificationScreen(email: 'explorer@questup.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('OTP Verification Screen renders without overflow on ultra-narrow 320px width',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OtpVerificationScreen(email: 'long.email.address.test@questup.com'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(OtpVerificationScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('LoginScreen and RegisterScreen render without overflow on 360px width',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Forgot Password Dialog renders without overflow on 320px width',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ForgotPasswordDialog(initialEmail: 'user@domain.com'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
