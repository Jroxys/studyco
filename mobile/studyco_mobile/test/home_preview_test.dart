import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/app.dart';
import 'package:studyco_mobile/app/debug/home_preview.dart';
import 'package:studyco_mobile/features/auth/debug/password_reset_preview.dart';
import 'package:studyco_mobile/features/auth/screens/login_screen.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';
import 'package:studyco_mobile/features/posts/screens/create_post_screen.dart';
import 'package:studyco_mobile/features/posts/screens/post_details_screen.dart';
import 'package:studyco_mobile/features/posts/widgets/post_card.dart';

void main() {
  testWidgets('Home debug entry preserves auth priority and normal login', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final authPreview = PasswordResetPreview.screen();
    if (authPreview != null) {
      expect(find.byType(authPreview.runtimeType), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    } else if (HomePreview.enabled) {
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byTooltip('Örnek veriler • Oturum açılmadı'), findsOneWidget);
      final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
      final selected =
          tester.widget<PostCard>(find.byType(PostCard).first).post;
      final arrow = find.byKey(ValueKey('open-${selected.id}'));
      await tester.ensureVisible(arrow);
      await tester.pumpAndSettle();
      await tester.tap(arrow);
      await tester.pumpAndSettle();
      expect(
        identical(
          tester.widget<PostDetailsScreen>(find.byType(PostDetailsScreen)).post,
          selected,
        ),
        isTrue,
      );
      expect(
        identical(
          tester
              .widget<PostDetailsScreen>(find.byType(PostDetailsScreen))
              .repository,
          home.repository,
        ),
        isTrue,
      );
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(find.byType(PostDetailsScreen), findsNothing);
      await tester.tap(find.byKey(const ValueKey('home-nav-1')));
      await tester.pumpAndSettle();
      final create = tester.widget<CreatePostScreen>(
        find.byType(CreatePostScreen),
      );
      expect(identical(create.repository, home.repository), isTrue);
      expect(identical(create.user, home.user), isTrue);
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(
        identical(tester.widget<HomeScreen>(find.byType(HomeScreen)), home),
        isTrue,
      );
      Navigator.of(tester.element(find.byType(HomeScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    } else {
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });
}
