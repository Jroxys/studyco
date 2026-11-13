import 'package:studyco_mobile/app/debug/home_preview.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/app.dart';
import 'package:studyco_mobile/features/auth/debug/password_reset_preview.dart';
import 'package:studyco_mobile/features/auth/screens/login_screen.dart';
import 'package:studyco_mobile/features/auth/screens/password_reset_screens.dart';

void main() {
  testWidgets(
    'Actual app startup respects debug selection and returns to login',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      final type = switch (PasswordResetPreview.selection) {
        'forgot' => ForgotPasswordScreen,
        'verify' => EmailVerificationScreen,
        'reset' => NewPasswordScreen,
        _ => HomePreview.enabled ? HomeScreen : LoginScreen,
      };
      expect(find.byType(type), findsOneWidget);
      if (type != LoginScreen && type != HomeScreen) {
        await tester.ensureVisible(find.text('Giriş Ekranına Dön'));
        await tester.tap(find.text('Giriş Ekranına Dön'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
