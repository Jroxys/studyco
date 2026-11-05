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
import 'package:studyco_mobile/features/applications/screens/applications_screen.dart';
import 'package:studyco_mobile/features/profile/screens/profile_screen.dart';
import 'package:studyco_mobile/features/applications/models/application.dart';
import 'package:studyco_mobile/features/posts/models/post.dart';
import 'package:studyco_mobile/features/reviews/screens/reviews_screen.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';

void main() {
  test(
    'development application fixture stays future-dated with explicit separate mock identity',
    () {
      final item = previewApplicationPost(now: DateTime(2035, 12, 31, 23, 59));
      expect(item.startsAt, DateTime(2036, 1, 2, 14));
      expect(item.endsAt.isAfter(item.startsAt), isTrue);
      expect(item.authorId, isNot(sampleHomeUser.postsOwnerId));
      expect(item.authorId, startsWith('mock-'));
      expect(item.id, startsWith('mock-'));
    },
  );
  testWidgets(
    'HOME_PREVIEW incoming fixtures use shared source for accept and automatic cancellation',
    (tester) async {
      if (!HomePreview.enabled || PasswordResetPreview.screen() != null) return;
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
      final source = home.repository.applicationsRepository!;
      expect(
        source
            .forOwner(home.user.postsOwnerId)
            .where((a) => a.postId == 'mock-preview-owned-post'),
        hasLength(3),
      );
      await tester.tap(find.byKey(const ValueKey('home-nav-3')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-incomingApplications')),
      );
      await tester.tap(
        find.byKey(const ValueKey('profile-incomingApplications')),
      );
      await tester.pumpAndSettle();
      final accept = find.byKey(const ValueKey('card-accept-mock-incoming-1'));
      await tester.ensureVisible(accept);
      await tester.tap(accept);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Kabul Et'));
      await tester.pumpAndSettle();
      expect(
        source.forOwner(home.user.postsOwnerId).first.status,
        ApplicationStatus.accepted,
      );
      expect(
        source
            .forOwner(home.user.postsOwnerId)
            .where((a) => a.postId == 'mock-preview-owned-post')
            .skip(1)
            .every((item) => item.status == ApplicationStatus.autoCancelled),
        isTrue,
      );
      expect(
        home.repository.posts
            .singleWhere((p) => p.id == 'mock-preview-owned-post')
            .status,
        PostStatus.booked,
      );
      expect(
        home.repository.discoverablePosts.any(
          (p) => p.id == 'mock-preview-owned-post',
        ),
        isFalse,
      );
    },
  );
  testWidgets(
    'HOME_PREVIEW received reviews use a separate shared mock source',
    (tester) async {
      if (!HomePreview.enabled || PasswordResetPreview.screen() != null) return;
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-nav-3')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-rating')),
          matching: find.text('4.7'),
        ),
        findsOneWidget,
      );
      expect(find.text('Değerlendirme sayısı: 3'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('profile-reviews')));
      await tester.tap(find.byKey(const ValueKey('profile-reviews')));
      await tester.pumpAndSettle();
      final screen = tester.widget<ReviewsScreen>(find.byType(ReviewsScreen));
      expect(screen.userId, sampleHomeUser.postsOwnerId);
      expect(screen.repository!.isLocal, isTrue);
      expect(find.text('Toplam 3 değerlendirme'), findsOneWidget);
      expect(find.text('4.7'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Değerlendirme sayısı: 3'), findsOneWidget);
    },
  );
  testWidgets(
    'HOME_PREVIEW author reviews match the listing ID and preserve the profile score',
    (tester) async {
      if (!HomePreview.enabled || PasswordResetPreview.screen() != null) return;
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('open-mock-preview-open-post'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      final owner = find.byKey(const ValueKey('detail-owner'));
      await tester.ensureVisible(owner);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: owner,
          matching: find.text('4.3 · 3 değerlendirme'),
        ),
        findsOneWidget,
      );
      await tester.tap(owner);
      await tester.pumpAndSettle();
      final screen = tester.widget<ReviewsScreen>(find.byType(ReviewsScreen));
      expect(screen.userId, previewTeacherId);
      expect(screen.ownReviews, isFalse);
      expect(find.text('Değerlendirmeler'), findsOneWidget);
      expect(find.text('4.3'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('apply-post')), findsOneWidget);
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-nav-3')));
      await tester.pumpAndSettle();
      expect(find.text('Değerlendirme sayısı: 3'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-rating')),
          matching: find.text('4.7'),
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'HOME_PREVIEW completed lesson review updates the same author source',
    (tester) async {
      if (!HomePreview.enabled || PasswordResetPreview.screen() != null) return;
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-nav-3')));
      await tester.pumpAndSettle();
      final menu = find.byKey(const ValueKey('profile-applications'));
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      final completed = find.byKey(
        const ValueKey('application-mock-completed-outgoing'),
      );
      await tester.ensureVisible(completed);
      await tester.tap(completed);
      await tester.pumpAndSettle();
      final review = find.text('Değerlendir');
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('5 yıldız'));
      await tester.pump();
      final send = find.widgetWithText(FilledButton, 'Gönder');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('Değerlendirmen kaydedildi.'), findsOneWidget);
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Değerlendirme sayısı: 3'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-nav-0')));
      await tester.pumpAndSettle();
      final post = find.byKey(const ValueKey('open-mock-preview-open-post'));
      await tester.ensureVisible(post);
      await tester.pumpAndSettle();
      await tester.tap(post);
      await tester.pumpAndSettle();
      expect(find.text('4.5 · 4 değerlendirme'), findsOneWidget);
    },
  );
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
      expect(selected.id, 'mock-preview-open-post');
      expect(selected.authorId, isNot(home.user.postsOwnerId));
      expect(selected.startsAt.isAfter(DateTime.now()), isTrue);
      expect(find.byKey(const ValueKey('apply-post')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('apply-post')));
      await tester.pumpAndSettle();
      final applications = home.repository.applicationsRepository!;
      expect(
        applications
            .forApplicant(home.user.postsOwnerId)
            .singleWhere((a) => a.postId == selected.id)
            .postId,
        selected.id,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('apply-post')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(find.byType(PostDetailsScreen), findsNothing);
      await tester.tap(find.byKey(const ValueKey('home-nav-3')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-applications')),
      );
      await tester.tap(find.byKey(const ValueKey('profile-applications')));
      await tester.pumpAndSettle();
      expect(find.byType(ApplicationsScreen), findsOneWidget);
      expect(find.text(selected.title), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
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
