import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/core/data/departments.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'package:studyco_mobile/features/posts/data/sample_posts.dart';
import 'package:studyco_mobile/features/posts/data/department_courses.dart';
import 'package:studyco_mobile/features/posts/models/post.dart';
import 'package:studyco_mobile/features/posts/screens/post_details_screen.dart';
import 'package:studyco_mobile/features/posts/screens/create_post_screen.dart';
import 'package:studyco_mobile/features/search/domain/post_search.dart';
import 'package:studyco_mobile/features/search/screens/search_screen.dart';
import 'package:studyco_mobile/features/search/widgets/search_post_card.dart';

Post listing(
  int index, {
  String title = 'İstatistik',
  String? department = 'Tıp',
  String topic = 'ÖLÇÜM ve IŞIK',
  String? description = 'Çalışma açıklaması',
  PostOffer offer = PostOffer.free,
  int coffee = 0,
  DateTime? createdAt,
  DateTime? startsAt,
  String location = 'Colombia',
}) => Post(
  id: 'post-$index',
  title: title,
  department: department,
  topic: topic,
  description: description,
  authorName: 'Öğrenci $index',
  createdAt: createdAt ?? DateTime(2026, 10, index + 1),
  startsAt: startsAt ?? DateTime(2026, 11, 2, 10),
  endsAt: DateTime(2026, 11, 2, 11),
  location: location,
  type: PostType.tutoring,
  subject: PostSubject.general,
  offer: offer,
  coffeeCount: coffee,
);

Finder menu(String label) => find.byWidgetPredicate(
  (w) => w is DropdownButtonFormField && w.decoration.labelText == label,
);

Future<void> select<T>(WidgetTester tester, String label, T value) async {
  tester.widget<DropdownButtonFormField<T>>(menu(label)).onChanged!(value);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Sample departments use canonical names and contain their listed courses',
    () {
      for (final post in samplePosts()) {
        expect(post.department, isNotNull, reason: post.id);
        expect(Departments.values, contains(post.department), reason: post.id);
        expect(
          DepartmentCourses.forDepartment(
            post.department,
          ).where((course) => !course.isOther).map((course) => course.title),
          contains(post.title),
          reason: post.id,
        );
      }
    },
  );

  test(
    'Sample department alone, course alone and their intersection return expected posts',
    () {
      final posts = samplePosts();
      expect(
        const PostSearch(
          department: Departments.computerEngineering,
        ).apply(posts),
        hasLength(4),
      );
      expect(
        const PostSearch(course: 'Algoritmalar').apply(posts).single.id,
        'algorithms',
      );
      expect(
        const PostSearch(
          department: Departments.computerEngineering,
          course: 'Algoritmalar',
        ).apply(posts).single.id,
        'algorithms',
      );
      expect(
        const PostSearch(
          department: Departments.softwareEngineering,
          course: 'Algoritmalar',
        ).apply(posts),
        isEmpty,
      );
    },
  );

  test(
    'Department and course intersect without inferring a missing or different department',
    () {
      final posts = [
        listing(
          0,
          title: 'Veri Yapıları',
          department: Departments.computerEngineering,
        ),
        listing(
          1,
          title: 'Veri Yapıları',
          department: Departments.softwareEngineering,
        ),
        listing(2, title: 'Veri Yapıları', department: null),
      ];
      expect(
        const PostSearch(course: 'Veri Yapıları').apply(posts),
        hasLength(3),
      );
      expect(
        const PostSearch(
          department: Departments.computerEngineering,
          course: 'Veri Yapıları',
        ).apply(posts).single.id,
        'post-0',
      );
      expect(
        const PostSearch(
          department: Departments.softwareEngineering,
          course: 'Veri Yapıları',
        ).apply(posts).single.id,
        'post-1',
      );
    },
  );

  testWidgets(
    'Sample Algorithms appears with course, department and combined UI filters',
    (tester) async {
      final repository = InMemoryPostsRepository(initialPosts: samplePosts());
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SearchScreen(repository: repository, user: sampleHomeUser),
        ),
      );
      await tester.pumpAndSettle();
      await select<String?>(tester, 'Ders', 'Algoritmalar');
      expect(find.text('1 ilan bulundu'), findsOneWidget);
      expect(
        tester.widget<SearchPostCard>(find.byType(SearchPostCard)).post.id,
        'algorithms',
      );
      await select<String?>(tester, 'Bölüm', Departments.computerEngineering);
      expect(tester.state<FormFieldState<String?>>(menu('Ders')).value, isNull);
      expect(find.text('4 ilan bulundu'), findsOneWidget);
      await select<String?>(tester, 'Ders', 'Algoritmalar');
      expect(find.text('1 ilan bulundu'), findsOneWidget);
      expect(
        tester.widget<SearchPostCard>(find.byType(SearchPostCard)).post.id,
        'algorithms',
      );
      await select<String?>(tester, 'Ders', null);
      expect(find.text('4 ilan bulundu'), findsOneWidget);
      await select<String?>(tester, 'Bölüm', Departments.softwareEngineering);
      expect(find.text('Uygun ilan bulunamadı'), findsOneWidget);
    },
  );

  test('Topic only search preserves Turkish casing and accents', () {
    final posts = [
      listing(0),
      listing(1, title: 'Eski', topic: '', description: null, department: null),
    ];
    for (final query in ['ölçüm', 'OLCUM', 'ışık', 'ISIK']) {
      expect(PostSearch(query: query).apply(posts).map((p) => p.id), [
        'post-0',
      ], reason: query);
    }
    for (final query in ['istatistik', 'çalışma', 'aciklamasi']) {
      expect(PostSearch(query: query).apply(posts), isEmpty);
    }
    expect(
      const PostSearch(query: '  ölçüm   ışık  ').apply(posts),
      hasLength(1),
    );
  });

  test(
    'StartsAt ascending ignores creation date and keeps deterministic ties',
    () {
      final posts = [
        listing(2, startsAt: DateTime(2027)),
        listing(1, startsAt: DateTime(2025)),
        listing(0, startsAt: DateTime(2025)),
      ];
      expect(const PostSearch().apply(posts).map((p) => p.id), [
        'post-0',
        'post-1',
        'post-2',
      ]);
      expect(posts.first.id, 'post-2');
    },
  );

  test('Max price includes free and all lower coffee amounts', () {
    final posts = [
      listing(0, coffee: 3), // Free offer overrides stale count.
      for (var count = 0; count <= 3; count++)
        listing(count + 1, offer: PostOffer.coffee, coffee: count),
    ];
    expect(const PostSearch().apply(posts), hasLength(5));
    for (final filter in CoffeeFilter.values.skip(1)) {
      final found = PostSearch(coffee: filter).apply(posts);
      expect(found, hasLength(filter.maxPrice! + 2));
      expect(found.first, same(posts.first));
    }
  });

  test('Department course location topic and max price intersect', () {
    final posts = [
      listing(0),
      listing(1, location: 'Library'),
      listing(2, department: 'Hukuk'),
      listing(3, title: 'Anatomi'),
      listing(4, offer: PostOffer.coffee, coffee: 3),
      listing(5, topic: 'Different'),
      listing(6, location: ' cOlOmBiA '),
      listing(7, location: '  '),
    ];
    expect(
      const PostSearch(
        query: 'ISIK',
        department: 'Tıp',
        course: 'İstatistik',
        location: 'Colombia',
        coffee: CoffeeFilter.two,
      ).apply(posts).map((p) => p.id),
      ['post-0', 'post-6'],
    );
  });

  test(
    'Courses merge prepared and manual titles by normalized identity, excluding Other',
    () {
      final posts = [
        listing(0, title: 'Tıbbi Terminoloji'),
        listing(1, title: ' tıbbi terminoloji '),
        listing(2, title: 'ANATOMİ'),
        listing(3, title: 'Diğer'),
        listing(4, title: 'Özel Hukuk', department: 'Hukuk'),
      ];
      final courses = PostSearch.courses(posts, 'Tıp');
      expect(courses, containsAll(['Anatomi', 'Tıbbi Terminoloji']));
      expect(
        courses.where((c) => normalizeSearch(c) == 'anatomi'),
        hasLength(1),
      );
      expect(
        courses.where((c) => normalizeSearch(c) == 'tibbi terminoloji'),
        hasLength(1),
      );
      expect(courses, isNot(contains('Diğer')));
      expect(courses, isNot(contains('Özel Hukuk')));
      expect(PostSearch.courses(posts, null), contains('Özel Hukuk'));
    },
  );

  late InMemoryPostsRepository repository;
  setUp(() {
    repository = InMemoryPostsRepository(
      initialPosts: List.generate(9, (i) => listing(i)),
    );
  });
  tearDown(() => repository.dispose());
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SearchScreen(repository: repository, user: sampleHomeUser),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Home keeps six newest; Search nav shows all and new posts reactively',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(repository: repository, user: sampleHomeUser),
        ),
      );
      await tester.pumpAndSettle();
      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      expect(grid.delegate.estimatedChildCount, 6);
      await tester.tap(find.byKey(const ValueKey('home-nav-2')));
      await tester.pumpAndSettle();
      expect(find.text('9 ilan bulundu'), findsOneWidget);
      expect(
        tester
            .widget<SearchPostCard>(find.byType(SearchPostCard).first)
            .post
            .id,
        'post-0',
      );
      await repository.addPost(listing(10, title: 'Tıbbi Terminoloji'));
      await tester.pumpAndSettle();
      expect(find.text('10 ilan bulundu'), findsOneWidget);
      expect(
        tester
            .widget<SearchPostCard>(find.byType(SearchPostCard).first)
            .post
            .id,
        'post-0',
      );
      await select<String?>(tester, 'Bölüm', 'Tıp');
      expect(
        tester
            .widget<DropdownButton<String?>>(
              find.descendant(
                of: menu('Ders'),
                matching: find.byType(DropdownButton<String?>),
              ),
            )
            .items!
            .map((e) => e.value),
        contains('Tıbbi Terminoloji'),
      );
      await select<String?>(tester, 'Ders', 'Tıbbi Terminoloji');
      expect(find.text('1 ilan bulundu'), findsOneWidget);
      await select<String?>(tester, 'Bölüm', 'Hukuk');
      expect(tester.state<FormFieldState<String?>>(menu('Ders')).value, isNull);
      expect(find.text('Uygun ilan bulunamadı'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-nav-0')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SliverGrid>(find.byType(SliverGrid))
            .delegate
            .estimatedChildCount,
        6,
      );
    },
  );

  testWidgets('Live query, simultaneous filters, sort, clear and empty state', (
    tester,
  ) async {
    await repository.addPost(
      listing(10, title: 'Özel Ders', offer: PostOffer.coffee, coffee: 3),
    );
    await open(tester);
    await tester.enterText(find.byKey(const ValueKey('search-query')), 'ışık');
    await select<String?>(tester, 'Bölüm', 'Tıp');
    await select<CoffeeFilter>(tester, 'Kahve', CoffeeFilter.two);
    expect(find.text('9 ilan bulundu'), findsOneWidget);
    await select<String?>(tester, 'Konum', 'Colombia');
    await tester.enterText(
      find.byKey(const ValueKey('search-query')),
      'olmayan',
    );
    await tester.pumpAndSettle();
    expect(find.text('Uygun ilan bulunamadı'), findsOneWidget);
    await tester.tap(find.byTooltip('Aramayı temizle'));
    await tester.pumpAndSettle();
    expect(find.text('9 ilan bulundu'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clear-search-filters')));
    await tester.pumpAndSettle();
    expect(find.text('10 ilan bulundu'), findsOneWidget);
    expect(tester.state<FormFieldState<String?>>(menu('Konum')).value, isNull);
  });

  testWidgets(
    'Correct detail instance without save control and filter/scroll preservation on back',
    (tester) async {
      await open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('search-query')),
        'ışık',
      );
      await select<String?>(tester, 'Bölüm', 'Tıp');
      await select<String?>(tester, 'Ders', 'İstatistik');
      await select<CoffeeFilter>(tester, 'Kahve', CoffeeFilter.free);
      await select<String?>(tester, 'Konum', 'Colombia');
      final target = find.byKey(const ValueKey('search-post-post-4'));
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable:
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      final scroll =
          tester
              .widget<CustomScrollView>(find.byType(CustomScrollView))
              .controller!;
      final offset = scroll.offset;
      await tester.tap(target);
      await tester.pumpAndSettle();
      final details = tester.widget<PostDetailsScreen>(
        find.byType(PostDetailsScreen),
      );
      expect(identical(details.post, repository.posts[4]), isTrue);
      expect(identical(details.repository, repository), isTrue);
      expect(find.byIcon(Icons.bookmark), findsNothing);
      expect(find.byIcon(Icons.bookmark_border), findsNothing);
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(scroll.offset, offset);
      expect(find.byKey(const ValueKey('search-save-post-4')), findsNothing);
      expect(find.byIcon(Icons.bookmark), findsNothing);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('search-query')))
            .controller!
            .text,
        'ışık',
      );
      expect(
        tester.state<FormFieldState<String?>>(menu('Konum')).value,
        'Colombia',
      );
      expect(tester.state<FormFieldState<String?>>(menu('Bölüm')).value, 'Tıp');
      expect(
        tester.state<FormFieldState<String?>>(menu('Ders')).value,
        'İstatistik',
      );
      expect(
        tester.state<FormFieldState<CoffeeFilter>>(menu('Kahve')).value,
        CoffeeFilter.free,
      );
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('320px search fits with text scale $scale and keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
          home: SearchScreen(repository: repository, user: sampleHomeUser),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Search and Create retain state on back and Home tab returns to Home',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(repository: repository, user: sampleHomeUser),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-nav-2')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('search-query')),
        'ışık',
      );
      await tester.tap(find.byKey(const ValueKey('home-nav-1')));
      await tester.pumpAndSettle();
      expect(
        identical(
          tester
              .widget<CreatePostScreen>(find.byType(CreatePostScreen))
              .repository,
          repository,
        ),
        isTrue,
      );
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('search-query')))
            .controller!
            .text,
        'ışık',
      );
      await tester.tap(find.byKey(const ValueKey('home-nav-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-nav-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-nav-0')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(SearchScreen), findsNothing);
      expect(find.byType(CreatePostScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test('Every department uses the shared course catalog', () {
    for (final department in Departments.values) {
      expect(PostSearch.courses([], department), isNotEmpty);
    }
  });
}
