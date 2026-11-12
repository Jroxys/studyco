import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/core/constants/app_university.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';
import 'package:studyco_mobile/features/home/widgets/home_bottom_navigation.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'support/discovery_fixtures.dart';
import 'package:studyco_mobile/features/posts/screens/create_post_screen.dart';
import 'package:studyco_mobile/features/profile/models/profile_destination.dart';
import 'package:studyco_mobile/features/profile/models/user_profile.dart';
import 'package:studyco_mobile/features/profile/screens/profile_screen.dart';
import 'package:studyco_mobile/features/reviews/screens/reviews_screen.dart';
import 'package:studyco_mobile/features/profile/widgets/profile_widgets.dart';
import 'package:studyco_mobile/features/search/screens/search_screen.dart';

const user = UserProfile(
  firstName: 'Deniz',
  university: 'Örnek Üniversitesi',
  department: 'Bilgisayar Mühendisliği',
  campus: 'Merkez',
);

void main() {
  Future<void> openProfile(
    WidgetTester tester, {
    UserProfile profile = user,
    double scale = 1,
    ValueChanged<ProfileDestination>? onOpenSection,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
        home: ProfileScreen(
          user: profile,
          onDestination: (_) {},
          onOpenSection: onOpenSection,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Profile accepts identity without a university field', (
    tester,
  ) async {
    const profile = UserProfile(
      firstName: 'Ece Yılmaz',
      department: 'Tıp',
      campus: 'Merkez',
    );
    await openProfile(tester, profile: profile);
    expect(find.text(profile.firstName), findsOneWidget);
    expect(find.text(profile.department), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('profile-university')))
          .data,
      studyCoUniversityName,
    );
  });

  testWidgets(
    'Profile shows provided identity and unavailable metrics without fabricated values',
    (tester) async {
      await openProfile(tester);
      expect(find.text(user.firstName), findsOneWidget);
      expect(find.text(user.department), findsOneWidget);
      expect(studyCoUniversityName, 'Sivas Cumhuriyet Üniversitesi');
      expect(find.text(studyCoUniversityName), findsOneWidget);
      expect(find.text(user.university), findsNothing);
      expect(find.text('Rümeysa'), findsNothing);
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      final rating = tester.getRect(
        find.byKey(const ValueKey('profile-rating')),
      );
      final tokens = tester.getRect(
        find.byKey(const ValueKey('profile-tokens')),
      );
      expect(tokens.top, greaterThan(rating.bottom));
      expect(tokens.left, rating.left);
      expect(tokens.width, rating.width);
      expect(
        tokens.width,
        tester.getSize(find.byType(ProfileIdentityCard)).width,
      );
      expect(find.text('Token Yükle'), findsOneWidget);
      expect(rating.height, greaterThanOrEqualTo(64));
      expect(tokens.height, greaterThanOrEqualTo(64));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-tokens')),
          matching: find.byIcon(Icons.local_cafe_outlined),
        ),
        findsOneWidget,
      );
      expect(find.text('Puan bilgisi alınamadı.'), findsOneWidget);
      expect(
        find.textContaining('Bakiye bilgisi henüz mevcut değil.'),
        findsOneWidget,
      );
      expect(find.byType(ProfileActionTile), findsNWidgets(6));
      expect(find.text('Yardım ve Destek'), findsNothing);
      expect(find.text('Kaydedilen İlanlar'), findsNothing);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
      expect(find.byTooltip('Profili Düzenle'), findsOneWidget);
      final activities = find.descendant(
        of: find.byKey(const ValueKey('profile-activities')),
        matching: find.byType(ProfileActionTile),
      );
      expect(
        tester
            .widgetList<ProfileActionTile>(activities)
            .map((tile) => tile.label),
        ['İlanlarım', 'Başvurularım', 'Gelen Başvurular', 'Değerlendirmelerim'],
      );
      final rows =
          activities
              .evaluate()
              .map((element) => tester.getRect(find.byWidget(element.widget)))
              .toList();
      for (var i = 1; i < rows.length; i++) {
        expect(rows[i].left, rows.first.left);
        expect(rows[i].top, greaterThan(rows[i - 1].bottom));
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-activities')),
          matching: find.byType(Divider),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-activities')),
          matching: find.byType(ProfilePanel),
        ),
        findsNWidgets(4),
      );
      expect(find.byKey(const ValueKey('profile-title')), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(4));
      expect(
        tester
            .widget<HomeBottomNavigation>(find.byType(HomeBottomNavigation))
            .selectedIndex,
        3,
      );
    },
  );

  testWidgets('Unfinished sections inform the user and keep the profile open', (
    tester,
  ) async {
    await openProfile(tester);
    for (final destination in ProfileDestination.values.where(
      (item) =>
          item != ProfileDestination.reviews &&
          item != ProfileDestination.edit &&
          item != ProfileDestination.settings &&
          item != ProfileDestination.logout,
    )) {
      ScaffoldMessenger.of(
        tester.element(find.byType(ProfileScreen)),
      ).hideCurrentSnackBar();
      await tester.pumpAndSettle();
      final key =
          destination == ProfileDestination.tokens
              ? 'profile-tokens'
              : 'profile-${destination.name}';
      final target = find.byKey(ValueKey(key));
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(
        find.text('${destination.label}: Bu bölüm henüz hazır değil.'),
        findsOneWidget,
      );
      expect(find.byType(ProfileScreen), findsOneWidget);
    }
  });

  testWidgets('Typed section callback is reusable for future child routes', (
    tester,
  ) async {
    final selected = <ProfileDestination>[];
    await openProfile(tester, onOpenSection: selected.add);
    await tester.tap(find.byKey(const ValueKey('profile-edit')));
    await tester.pumpAndSettle();
    expect(selected, [ProfileDestination.edit]);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Rating card opens received reviews and Back restores Profile', (
    tester,
  ) async {
    await openProfile(tester);
    await tester.tap(find.byKey(const ValueKey('profile-rating')));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewsScreen), findsOneWidget);
    expect(
      find.text('Değerlendirmeler şu anda görüntülenemiyor.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets(
    'The first three cards grow when more vertical space is available',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPadding);
      final heights = <List<double>>[];
      for (final height in [844.0, 915.0]) {
        tester.view.physicalSize = Size(412, height);
        await openProfile(tester);
        heights.add([
          tester.getSize(find.byType(ProfileIdentityCard)).height,
          tester.getSize(find.byKey(const ValueKey('profile-rating'))).height,
          tester.getSize(find.byKey(const ValueKey('profile-tokens'))).height,
        ]);
        expect(tester.takeException(), isNull);
      }
      for (var index = 0; index < 3; index++) {
        expect(heights.last[index], greaterThan(heights.first[index]));
      }
    },
  );

  for (final size in [const Size(390, 844), const Size(412, 915)]) {
    testWidgets('All primary actions fit without scrolling at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openProfile(tester);
      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('profile-scroll')),
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        0,
      );
      expect(
        find.byKey(const ValueKey('profile-logout')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      final nav = tester.getRect(find.byType(HomeBottomNavigation));
      expect(
        tester.getSize(find.byType(ProfileIdentityCard)).height,
        greaterThan(110),
      );
      for (final item in ['rating', 'tokens']) {
        expect(
          tester.getSize(find.byKey(ValueKey('profile-$item'))).height,
          greaterThanOrEqualTo(70),
        );
      }
      final activities = [
        'posts',
        'applications',
        'incomingApplications',
        'reviews',
      ];
      for (var i = 0; i < activities.length; i++) {
        final rect = tester.getRect(
          find.byKey(ValueKey('profile-${activities[i]}')),
        );
        expect(rect.height, inInclusiveRange(56, 58));
        if (i > 0) {
          final previous = tester.getRect(
            find.byKey(ValueKey('profile-${activities[i - 1]}')),
          );
          expect(rect.top - previous.bottom, inInclusiveRange(3, 6));
          expect(rect.left, previous.left);
          expect(rect.width, previous.width);
        }
      }
      final settings = tester.getRect(
        find.byKey(const ValueKey('profile-settings')),
      );
      final logout = tester.getRect(
        find.byKey(const ValueKey('profile-logout')),
      );
      expect(settings.width, closeTo(logout.width, .01));
      expect(settings.top, logout.top);
      expect(logout.left - settings.right, 8);
      for (final item in ['settings', 'logout']) {
        expect(
          tester.getSize(find.byKey(ValueKey('profile-$item'))).height,
          greaterThanOrEqualTo(64),
        );
      }
      for (final item in [
        'posts',
        'applications',
        'incomingApplications',
        'reviews',
        'settings',
        'logout',
      ]) {
        expect(
          tester.getRect(find.byKey(ValueKey('profile-$item'))).bottom,
          lessThanOrEqualTo(nav.top),
        );
      }
    });
  }

  for (final size in [const Size(320, 568), const Size(360, 800)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '${size.width}px and long identity fit with text scale $scale and scroll as needed',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await openProfile(
            tester,
            scale: scale,
            profile: const UserProfile(
              firstName: 'Çok Uzun Adı Olan Kullanıcı',
              university:
                  'Sivas Cumhuriyet Üniversitesi ve Uzun Üniversite Adı',
              department: 'Elektrik-Elektronik Mühendisliği',
              campus: 'Merkez',
            ),
          );
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(
            find.byKey(const ValueKey('profile-logout')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('profile-logout')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          expect(
            tester.getRect(find.byType(HomeBottomNavigation)).bottom,
            size.height,
          );
        },
      );
    }
  }

  Future<InMemoryPostsRepository> openHome(WidgetTester tester) async {
    final repository = InMemoryPostsRepository(
      initialPosts: activeSamplePosts(),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          repository: repository,
          user: user,
          onCreatePost:
              () => Navigator.of(
                tester.element(find.byType(HomeScreen)),
              ).push<bool>(
                MaterialPageRoute(
                  builder:
                      (_) =>
                          CreatePostScreen(repository: repository, user: user),
                ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  Future<void> nav(WidgetTester tester, int index) async {
    await tester.tap(find.byKey(ValueKey('home-nav-$index')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Home Profile tab and header open the current user and Back restores Home',
    (tester) async {
      await openHome(tester);
      await nav(tester, 3);
      final logo = find.byWidgetPredicate(
        (w) => w is Image && w.semanticLabel == 'StudyCo',
      );
      expect(logo, findsOneWidget);
      expect(
        tester.getCenter(logo).dx,
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
      );
      expect(tester.getSize(logo).height, 32);
      expect(find.byType(BackButton), findsOneWidget);
      expect(
        identical(
          tester.widget<ProfileScreen>(find.byType(ProfileScreen)).user,
          user,
        ),
        isTrue,
      );
      await nav(tester, 0);
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Profilim'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Search Profile and return preserve query; Create Profile preserves draft',
    (tester) async {
      await openHome(tester);
      await nav(tester, 2);
      await tester.enterText(
        find.byKey(const ValueKey('search-query')),
        'Algoritmalar',
      );
      await nav(tester, 3);
      await nav(tester, 2);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('search-query')))
            .controller!
            .text,
        'Algoritmalar',
      );
      await nav(tester, 0);
      await nav(tester, 1);
      final topic = find.byKey(const ValueKey('post-topic'));
      await tester.ensureVisible(topic);
      await tester.enterText(topic, 'Korunan taslak');
      await nav(tester, 3);
      await nav(tester, 1);
      expect(
        tester.widget<TextFormField>(topic).controller!.text,
        'Korunan taslak',
      );
      await nav(tester, 3);
      await nav(tester, 0);
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Profile opens Search and Create with shared repository and Home returns correctly',
    (tester) async {
      final repository = await openHome(tester);
      await nav(tester, 3);
      await nav(tester, 2);
      expect(
        identical(
          tester.widget<SearchScreen>(find.byType(SearchScreen)).repository,
          repository,
        ),
        isTrue,
      );
      await nav(tester, 0);
      expect(find.byType(HomeScreen), findsOneWidget);
      await nav(tester, 3);
      await nav(tester, 1);
      expect(
        identical(
          tester
              .widget<CreatePostScreen>(find.byType(CreatePostScreen))
              .repository,
          repository,
        ),
        isTrue,
      );
      await nav(tester, 0);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ProfileScreen), findsNothing);
    },
  );
}
