import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/app.dart';
import 'package:studyco_mobile/app/debug/home_preview.dart';
import 'package:studyco_mobile/features/auth/debug/password_reset_preview.dart';

/// Login interaction tests retain the real app but start below the Home demo route.
Future<void> pumpLoginApp(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  if (HomePreview.enabled && PasswordResetPreview.screen() == null) {
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();
  }
}
