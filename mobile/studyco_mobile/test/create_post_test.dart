import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/core/data/academic_catalog.dart';
import 'package:studyco_mobile/core/widgets/academic_catalog_scope.dart';
import 'package:studyco_mobile/features/posts/domain/location_catalog.dart';
import 'package:studyco_mobile/features/posts/widgets/location_catalog_scope.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/core/data/departments.dart';
import 'package:studyco_mobile/features/posts/data/department_courses.dart';
import 'package:studyco_mobile/features/posts/data/campus_locations.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';
import 'package:studyco_mobile/features/home/widgets/home_bottom_navigation.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'support/discovery_fixtures.dart';
import 'package:studyco_mobile/features/posts/models/post.dart';
import 'package:studyco_mobile/features/posts/screens/create_post_screen.dart';
import 'package:studyco_mobile/features/posts/validation/create_post_validators.dart';
import 'package:studyco_mobile/features/posts/widgets/post_card.dart';
import 'package:studyco_mobile/features/posts/widgets/post_location_field.dart';
import 'package:studyco_mobile/features/profile/models/user_profile.dart';
import 'package:studyco_mobile/features/search/screens/search_screen.dart';
import 'package:studyco_mobile/features/search/domain/post_search.dart';

class PendingRepository extends InMemoryPostsRepository {
  final requests = <Post>[];
  Completer<void> pending = Completer<void>();
  @override
  Future<void> addPost(Post post) async {
    requests.add(post);
    await pending.future;
    await super.addPost(post);
  }
}

Future<void> reveal(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await reveal(tester, key);
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String value) async {
  await reveal(tester, key);
  await tester.enterText(find.byKey(ValueKey(key)), value);
  await tester.pumpAndSettle();
}

Future<void> pickSchedule(
  WidgetTester tester, {
  DateTime? date,
  int endHour = 15,
}) async {
  await tapKey(tester, 'post-date');
  final dialog = find.byType(DatePickerDialog);
  Navigator.of(tester.element(dialog)).pop(
    date ?? DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 2)),
  );
  await tester.pumpAndSettle();
  for (final entry in {'post-start': 14, 'post-end': endHour}.entries) {
    await tapKey(tester, entry.key);
    Navigator.of(
      tester.element(find.byType(TimePickerDialog)),
    ).pop(TimeOfDay(hour: entry.value, minute: 0));
    await tester.pumpAndSettle();
  }
}

Finder courseField() => find.descendant(
  of: find.byKey(const ValueKey('post-course')),
  matching: find.byType(DropdownButtonFormField<DepartmentCourse>),
);

Future<void> selectDepartment(WidgetTester tester, String department) async {
  final previous =
      tester
          .state<FormFieldState<String>>(
            find.byKey(const ValueKey('post-department')),
          )
          .value;
  await tapKey(tester, 'post-department');
  final delta =
      Departments.values.indexOf(department) <
              Departments.values.indexOf(previous ?? '')
          ? 100.0
          : -100.0;
  for (
    var attempt = 0;
    attempt < 30 && find.text(department).hitTestable().evaluate().isEmpty;
    attempt++
  ) {
    await tester.drag(find.byType(Scrollable).last, Offset(0, delta));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(department).hitTestable().last);
  await tester.pumpAndSettle();
}

Future<void> selectCourse(WidgetTester tester, String course) async {
  await tapKey(tester, 'post-course');
  await tester.tap(find.text(course).last);
  await tester.pumpAndSettle();
}

Finder locationField() => find.descendant(
  of: find.byKey(const ValueKey('post-location-option')),
  matching: find.byType(DropdownButtonFormField<String>),
);

Future<void> selectLocation(WidgetTester tester, String location) async {
  await tapKey(tester, 'post-location-option');
  await tester.tap(find.text(location).last);
  await tester.pumpAndSettle();
}

Future<void> fill(
  WidgetTester tester, {
  int coffee = 0,
  String department = Departments.computerEngineering,
  String course = 'Python Programlama',
  bool withLocation = true,
}) async {
  await selectDepartment(tester, department);
  await selectCourse(tester, course);
  await enter(tester, 'post-topic', 'Döngüler ve fonksiyonlar');
  await pickSchedule(tester);
  if (withLocation) await selectLocation(tester, 'Espressolab');
  await tapKey(tester, 'offer-$coffee');
}

Future<void> openForm(
  WidgetTester tester,
  InMemoryPostsRepository repository, {
  LocationCatalog? catalog,
  AcademicCatalog? academicCatalog,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder:
          (_, child) => LocationCatalogScope(
            catalog: catalog ?? CampusLocations.catalog,
            child: AcademicCatalogScope(
              catalog: academicCatalog ?? AcademicCatalog.temporary,
              child: child!,
            ),
          ),
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed:
                    () => Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder:
                            (_) => CreatePostScreen(
                              repository: repository,
                              user: sampleHomeUser,
                            ),
                      ),
                    ),
                child: const Text('Open'),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Existing topic data remains available alongside optional descriptions',
    () {
      final legacy = activeSamplePosts().first;
      expect(legacy.topic, 'Python Programlama');
      expect(legacy.description, isNull);
    },
  );

  test(
    'Required text and schedule rules reject missing, elapsed and cross-day lessons',
    () {
      final now = DateTime(2030, 1, 1, 12);
      final start = DateTime(2030, 1, 2, 14);
      expect(CreatePostValidators.requiredText('  '), isNotNull);
      expect(CreatePostValidators.requiredText(' Topic '), isNull);
      expect(CreatePostValidators.schedule(null, null, now: now), isNotNull);
      expect(
        CreatePostValidators.schedule(
          now,
          now.add(const Duration(hours: 1)),
          now: now,
        ),
        isNotNull,
      );
      expect(
        CreatePostValidators.schedule(
          now.subtract(const Duration(minutes: 1)),
          start,
          now: now,
        ),
        isNotNull,
      );
      expect(CreatePostValidators.schedule(start, start, now: now), isNotNull);
      expect(
        CreatePostValidators.schedule(
          start,
          start.subtract(const Duration(hours: 1)),
          now: now,
        ),
        isNotNull,
      );
      expect(
        CreatePostValidators.schedule(
          start,
          start.add(const Duration(days: 1)),
          now: now,
        ),
        isNotNull,
      );
      expect(
        CreatePostValidators.schedule(
          start,
          start.add(const Duration(hours: 1)),
          now: now,
        ),
        isNull,
      );
      expect(
        CreatePostValidators.schedule(
          start,
          start.add(const Duration(hours: 1)),
          now: start,
        ),
        isNotNull,
      );
    },
  );

  testWidgets(
    'Empty form validates all required inputs and has no real map selection',
    (tester) async {
      final repository = InMemoryPostsRepository();
      addTearDown(repository.dispose);
      await openForm(tester, repository);
      expect(
        tester
            .widget<HomeBottomNavigation>(find.byType(HomeBottomNavigation))
            .selectedIndex,
        1,
      );
      for (final key in ['post-topic', 'post-description']) {
        expect(
          tester
              .widget<TextFormField>(find.byKey(ValueKey(key)))
              .controller!
              .text,
          isEmpty,
        );
      }
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const ValueKey('post-department')),
            )
            .initialValue,
        isNull,
      );
      expect(find.byKey(const ValueKey('post-topic')), findsOneWidget);
      expect(find.text('Konu *'), findsOneWidget);
      expect(find.byKey(const ValueKey('map-select')), findsNothing);
      expect(find.byIcon(Icons.map_outlined), findsNothing);
      for (final text in [
        'Örnek konumlar',
        'Haritada Seç',
        'Görsel yer tutucu • Harita seçimi henüz hazır değil.',
        'Buluşma noktasını yukarıdaki listeden seçin.',
      ]) {
        expect(find.text(text), findsNothing);
      }
      expect(find.byKey(const ValueKey('post-location')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(PostLocationField),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      expect(
        tester.state<FormFieldState<String>>(locationField()).value,
        isNull,
      );

      await tapKey(tester, 'publish-post');
      for (final key in ['post-topic']) {
        expect(
          tester
              .state<FormFieldState<String>>(find.byKey(ValueKey(key)))
              .errorText,
          'Bu alan zorunludur.',
          reason: key,
        );
      }
      expect(
        tester.state<FormFieldState<String>>(locationField()).errorText,
        'Listeden bir buluşma noktası seçin.',
      );
      expect(find.text('İlgili bölümü seçin.'), findsOneWidget);
      expect(
        tester.state<FormFieldState<DepartmentCourse>>(courseField()).errorText,
        'Önce ilgili bölümü seçin.',
      );
      expect(find.text('Tarih ve iki saati seçin.'), findsOneWidget);
      expect(find.text('Ders karşılığını seçin.'), findsOneWidget);
      expect(repository.posts, isEmpty);
    },
  );

  for (final emptyTopic in ['', '   ']) {
    testWidgets(
      'Topic rejects ${emptyTopic.isEmpty ? 'empty' : 'whitespace'} then publishes trimmed input',
      (tester) async {
        final repository = InMemoryPostsRepository();
        addTearDown(repository.dispose);
        await openForm(tester, repository);
        final topic = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const ValueKey('post-topic')),
            matching: find.byType(TextField),
          ),
        );
        expect(topic.decoration!.labelText, 'Konu *');
        expect(
          topic.decoration!.hintText,
          'Örn. Bağlı Listeler ve İkili Arama Ağaçları',
        );
        final positions =
            ['post-department', 'post-course', 'post-topic', 'post-description']
                .map((key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy)
                .toList();
        expect(positions, orderedEquals([...positions]..sort()));
        await fill(tester);
        await enter(tester, 'post-topic', emptyTopic);
        await tapKey(tester, 'publish-post');
        expect(repository.posts, isEmpty);
        expect(find.byType(CreatePostScreen), findsOneWidget);
        expect(
          tester
              .state<FormFieldState<String>>(
                find.byKey(const ValueKey('post-topic')),
              )
              .errorText,
          'Bu alan zorunludur.',
        );
        await enter(
          tester,
          'post-topic',
          '  Bağlı Listeler ve İkili Arama Ağaçları  ',
        );
        await tapKey(tester, 'publish-post');
        final post = repository.posts.single;
        expect(post.topic, 'Bağlı Listeler ve İkili Arama Ağaçları');
        expect(post.title, 'Python Programlama');
        expect(post.topic, isNot(post.title));
        expect(post.description, isNull);
        expect(find.byType(CreatePostScreen), findsNothing);
      },
    );
  }

  for (var coffee = 0; coffee <= 3; coffee++) {
    testWidgets(
      'Offer $coffee publishes tutoring with a required independent topic without a map',
      (tester) async {
        final repository = InMemoryPostsRepository();
        addTearDown(repository.dispose);
        await openForm(tester, repository);
        await fill(tester, coffee: coffee);
        final before = DateTime.now().toUtc();
        await tapKey(tester, 'publish-post');
        expect(find.byType(CreatePostScreen), findsNothing);
        final post = repository.posts.single;
        expect(post.type, PostType.tutoring);
        expect(post.subject, PostSubject.coding);
        expect(post.department, Departments.computerEngineering);
        expect(post.topic, 'Döngüler ve fonksiyonlar');
        expect(post.title, 'Python Programlama');
        expect(post.description, isNull);
        expect(post.authorName, sampleHomeUser.firstName);
        expect(post.location, 'Espressolab');
        expect(post.coffeeCount, coffee);
        expect(post.offer, coffee == 0 ? PostOffer.free : PostOffer.coffee);
        expect(post.createdAt.isUtc, isTrue);
        expect(post.createdAt.isBefore(before), isFalse);
        expect(post.endsAt.difference(post.startsAt), const Duration(hours: 1));
      },
    );
  }

  testWidgets(
    'Schedule is checked again at publication and invalid times keep the form',
    (tester) async {
      final repository = InMemoryPostsRepository();
      addTearDown(repository.dispose);
      await openForm(tester, repository);
      await fill(tester);
      await pickSchedule(tester, endHour: 13);
      await tapKey(tester, 'publish-post');
      expect(find.text('Bitiş başlangıçtan sonra olmalıdır.'), findsOneWidget);
      expect(repository.posts, isEmpty);
      await pickSchedule(tester, date: DateTime(2020, 1, 1));
      await tapKey(tester, 'publish-post');
      expect(find.text('Başlangıç gelecekte olmalıdır.'), findsOneWidget);
      expect(repository.posts, isEmpty);
    },
  );

  testWidgets(
    'Double submission is coalesced; failure preserves inputs and retry succeeds',
    (tester) async {
      final repository = PendingRepository();
      addTearDown(repository.dispose);
      await openForm(tester, repository);
      await fill(tester, coffee: 2);
      await enter(tester, 'post-description', 'Sınav hazırlığı');
      await reveal(tester, 'publish-post');
      final submit =
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('publish-post')))
              .onPressed!;
      submit();
      submit();
      await tester.pump();
      expect(repository.requests, hasLength(1));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('publish-post')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<AbsorbPointer>(
              find
                  .descendant(
                    of: find.byType(Form),
                    matching: find.byType(AbsorbPointer),
                  )
                  .first,
            )
            .absorbing,
        isTrue,
      );
      repository.pending.completeError(StateError('unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.text('İlan eklenemedi. Bilgileriniz korundu; tekrar deneyin.'),
        findsOneWidget,
      );
      expect(
        tester
            .state<FormFieldState<DepartmentCourse>>(courseField())
            .value!
            .title,
        'Python Programlama',
      );
      expect(
        tester
            .state<FormFieldState<String>>(
              find.byKey(const ValueKey('post-department')),
            )
            .value,
        Departments.computerEngineering,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('post-description')),
            )
            .controller!
            .text,
        'Sınav hazırlığı',
      );
      expect(repository.posts, isEmpty);
      repository.pending = Completer<void>();
      await reveal(tester, 'publish-post');
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('publish-post')))
          .onPressed!();
      await tester.pump();
      repository.pending.complete();
      await tester.pumpAndSettle();
      expect(repository.posts.single.description, 'Sınav hazırlığı');
      expect(repository.requests.map((p) => p.id).toSet(), hasLength(2));
    },
  );

  for (final entry in {'İşletme': 'Genel Muhasebe', 'Tıp': 'Anatomi'}.entries) {
    testWidgets(
      'Shared Home repository shows ${entry.key}, keeps the newest six and all older posts',
      (tester) async {
        final initial = activeSamplePosts();
        final repository = InMemoryPostsRepository(
          initialPosts: [
            ...initial,
            for (var index = 0; index < 4; index++)
              Post(
                authorId: 'fixture-owner',
                id: 'old-$index',
                title: 'Older',
                topic: 'Old topic',
                authorName: 'Student',
                createdAt: DateTime.utc(2020, 1, index + 1),
                startsAt: DateTime(2030, 1, 1, 14),
                endsAt: DateTime(2030, 1, 1, 15),
                location: 'Library',
                type: PostType.tutoring,
                subject: PostSubject.coding,
                offer: PostOffer.free,
              ),
          ],
        );
        addTearDown(repository.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder:
                  (context) => HomeScreen(
                    repository: repository,
                    user: sampleHomeUser,
                    onCreatePost:
                        () => Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder:
                                (_) => CreatePostScreen(
                                  repository: repository,
                                  user: sampleHomeUser,
                                ),
                          ),
                        ),
                  ),
            ),
          ),
        );
        await tester.pumpAndSettle();
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
        await fill(tester, department: entry.key, course: entry.value);
        await tapKey(tester, 'publish-post');
        expect(find.byType(CreatePostScreen), findsNothing);
        expect(find.byType(ChoiceChip), findsNothing);
        final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
        expect(grid.delegate.estimatedChildCount, 6);
        final delegate = grid.delegate as SliverChildBuilderDelegate;
        final first =
            delegate.builder(tester.element(find.byType(SliverGrid)), 0)!
                as PostCard;
        expect(first.post.title, entry.value);
        expect(first.post.subject, PostSubject.general);
        expect(repository.posts.length, 9);
        expect(
          repository.posts.map((post) => post.id),
          containsAll(initial.map((post) => post.id)),
        );
        expect(
          find.byKey(ValueKey('post-${repository.posts.last.id}')),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('Back, Home, inactive targets and location selection work', (
    tester,
  ) async {
    final repository = InMemoryPostsRepository();
    addTearDown(repository.dispose);
    await openForm(tester, repository);
    await tester.tap(find.byKey(const ValueKey('home-nav-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-query')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    tester
        .widget<PostLocationField>(find.byType(PostLocationField))
        .onLocationChanged('Fen Fakültesi');
    await tester.pumpAndSettle();
    expect(
      tester.widget<PostLocationField>(find.byType(PostLocationField)).value,
      isNull,
    );
    await selectLocation(tester, CampusLocations.values.first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<PostLocationField>(find.byType(PostLocationField)).value,
      CampusLocations.values.first,
    );
    expect(
      tester.state<FormFieldState<String>>(locationField()).value,
      CampusLocations.values.first,
    );
    await tester.tap(find.byKey(const ValueKey('home-nav-0')));
    await tester.pumpAndSettle();
    expect(find.byType(CreatePostScreen), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.byType(CreatePostScreen), findsNothing);
    expect(repository.posts, isEmpty);
  });

  test('Every shared department has 3–5 prepared courses and Other last', () {
    expect(
      DepartmentCourses.byDepartment.keys,
      unorderedEquals(Departments.values),
    );
    for (final department in Departments.values) {
      final courses = DepartmentCourses.forDepartment(department);
      final prepared = courses.where((course) => !course.isOther).toList();
      expect(prepared.length, inInclusiveRange(3, 5), reason: department);
      expect(courses.last.isOther, isTrue, reason: department);
      expect(courses.last.title, 'Diğer');
      expect(courses.where((course) => course.isOther), hasLength(1));
      expect(
        courses.map((course) => course.title).toSet(),
        hasLength(courses.length),
      );
      if (![
        Departments.computerEngineering,
        Departments.softwareEngineering,
      ].contains(department)) {
        expect(
          courses.map((course) => course.subject),
          everyElement(PostSubject.general),
          reason: department,
        );
      }
    }
    expect(DepartmentCourses.forDepartment(null), isEmpty);
  });

  testWidgets(
    'Department changes clear prepared and manual course selections independently of description',
    (tester) async {
      final repository = InMemoryPostsRepository();
      addTearDown(repository.dispose);
      await openForm(tester, repository);
      final departmentItems = tester
          .widget<DropdownButton<String>>(
            find.descendant(
              of: find.byKey(const ValueKey('post-department')),
              matching: find.byType(DropdownButton<String>),
            ),
          )
          .items!
          .map((item) => item.value);
      expect(departmentItems, Departments.values);
      expect(
        tester
            .widget<DropdownButtonFormField<DepartmentCourse>>(courseField())
            .onChanged,
        isNull,
      );
      await selectDepartment(tester, Departments.computerEngineering);
      await selectCourse(tester, 'Lineer Cebir');
      expect(find.text('Ana Sayfa kategorisi: Matematik'), findsOneWidget);
      expect(find.byKey(const ValueKey('post-manual-title')), findsNothing);
      await enter(tester, 'post-description', 'Vektör uzayları');
      await selectDepartment(tester, Departments.softwareEngineering);
      expect(
        tester.state<FormFieldState<DepartmentCourse>>(courseField()).value,
        isNull,
      );
      final courses =
          tester
              .widget<DropdownButton<DepartmentCourse>>(
                find.descendant(
                  of: courseField(),
                  matching: find.byType(DropdownButton<DepartmentCourse>),
                ),
              )
              .items!;
      expect(
        courses.map((item) => item.value!.title),
        isNot(contains('Lineer Cebir')),
      );
      await selectCourse(tester, 'Diğer');
      await enter(tester, 'post-manual-title', 'Özel ders adı');
      await selectDepartment(tester, 'Hukuk');
      expect(
        tester.state<FormFieldState<DepartmentCourse>>(courseField()).value,
        isNull,
      );
      expect(find.byKey(const ValueKey('post-manual-title')), findsNothing);
      await selectCourse(tester, 'Diğer');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('post-manual-title')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('post-description')),
            )
            .controller!
            .text,
        'Vektör uzayları',
      );
      await selectDepartment(tester, Departments.computerEngineering);
      await tapKey(tester, 'publish-post');
      expect(
        tester.state<FormFieldState<DepartmentCourse>>(courseField()).errorText,
        'Bu bölüme ait bir ders seçin.',
      );
      expect(repository.posts, isEmpty);
    },
  );

  testWidgets(
    'Other validates whitespace, hides for prepared lessons and persists the trimmed manual title',
    (tester) async {
      final repository = InMemoryPostsRepository();
      addTearDown(repository.dispose);
      await openForm(tester, repository);
      await fill(tester, department: 'Tıp', course: 'Anatomi');
      expect(find.byKey(const ValueKey('post-manual-title')), findsNothing);
      await selectCourse(tester, 'Diğer');
      await enter(tester, 'post-manual-title', '   ');
      await tapKey(tester, 'publish-post');
      expect(
        tester
            .state<FormFieldState<String>>(
              find.byKey(const ValueKey('post-manual-title')),
            )
            .errorText,
        'Bu alan zorunludur.',
      );
      expect(repository.posts, isEmpty);
      await enter(tester, 'post-manual-title', 'Saklanmayacak ders');
      await selectCourse(tester, 'Fizyoloji');
      expect(find.byKey(const ValueKey('post-manual-title')), findsNothing);
      await selectCourse(tester, 'Diğer');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('post-manual-title')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await enter(tester, 'post-manual-title', '  Tıbbi Terminoloji  ');
      await tapKey(tester, 'publish-post');
      final post = repository.posts.single;
      expect(post.title, 'Tıbbi Terminoloji');
      expect(post.department, 'Tıp');
      expect(
        const PostSearch(
          department: 'Tıp',
          course: 'Tıbbi Terminoloji',
        ).apply(repository.posts).single,
        same(post),
      );
      expect(post.topic, 'Döngüler ve fonksiyonlar');
      expect(post.subject, PostSubject.general);
      expect(find.byType(CreatePostScreen), findsNothing);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SearchScreen(repository: repository, user: sampleHomeUser),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 ilan bulundu'), findsOneWidget);
      expect(find.byKey(ValueKey('search-post-${post.id}')), findsOneWidget);
      expect(
        PostSearch.courses(repository.posts, 'Tıp'),
        contains('Tıbbi Terminoloji'),
      );
    },
  );

  for (final department in Departments.values) {
    testWidgets('Prepared course can be published for $department', (
      tester,
    ) async {
      final repository = InMemoryPostsRepository();
      addTearDown(repository.dispose);
      final course = DepartmentCourses.forDepartment(department).first;
      await openForm(tester, repository);
      await fill(tester, department: department, course: course.title);
      await tapKey(tester, 'publish-post');
      final post = repository.posts.single;
      expect(post.department, department);
      expect(post.title, course.title);
      expect(post.subject, course.subject);
      expect(post.topic, 'Döngüler ve fonksiyonlar');
      expect(post.type, PostType.tutoring);
      expect(find.byType(CreatePostScreen), findsNothing);
    });
  }

  testWidgets(
    'A mathematics lesson persists department, title and the existing Home category and topic',
    (tester) async {
      final repository = InMemoryPostsRepository();
      addTearDown(repository.dispose);
      await openForm(tester, repository);
      await fill(tester);
      await selectCourse(tester, 'Lineer Cebir');
      await tapKey(tester, 'publish-post');
      final post = repository.posts.single;
      expect(post.department, Departments.computerEngineering);
      expect(post.title, 'Lineer Cebir');
      expect(post.topic, 'Döngüler ve fonksiyonlar');
      expect(post.subject, PostSubject.mathematics);
    },
  );

  testWidgets(
    'Location menu uses a central allowlist, has no text entry and saves the selected name',
    (tester) async {
      final repository = InMemoryPostsRepository();
      addTearDown(repository.dispose);
      await openForm(tester, repository);
      final field = tester.widget<PostLocationField>(
        find.byType(PostLocationField),
      );
      expect(field.locationOptions, CampusLocations.values);
      final menu = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: locationField(),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(menu.items!.map((item) => item.value), CampusLocations.values);
      expect(menu.items!.map((item) => item.value), isNot(contains('Diğer')));
      expect(
        find.descendant(
          of: find.byType(PostLocationField),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      expect(
        find.text(
          'Geçici örnek konumlar; kampüs içi uygunlukları henüz doğrulanmadı.',
        ),
        findsOneWidget,
      );
      await fill(tester, withLocation: false);
      await tapKey(tester, 'publish-post');
      expect(repository.posts, isEmpty);
      expect(
        tester.state<FormFieldState<String>>(locationField()).errorText,
        'Listeden bir buluşma noktası seçin.',
      );
      field.onLocationChanged('Listede olmayan bir yer');
      await tester.pumpAndSettle();
      expect(
        tester.widget<PostLocationField>(find.byType(PostLocationField)).value,
        isNull,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(locationField())
            .validator!('Listede olmayan bir yer'),
        'Listeden bir buluşma noktası seçin.',
      );
      await tapKey(tester, 'publish-post');
      expect(repository.posts, isEmpty);
      expect(
        tester.state<FormFieldState<String>>(locationField()).errorText,
        'Listeden bir buluşma noktası seçin.',
      );
      await selectLocation(tester, 'Colombia');
      expect(
        tester.widget<PostLocationField>(find.byType(PostLocationField)).value,
        'Colombia',
      );
      await tapKey(tester, 'publish-post');
      expect(repository.posts.single.location, 'Colombia');
      expect(find.byType(CreatePostScreen), findsNothing);
    },
  );

  testWidgets(
    'Replacement catalog alone controls selection and saved location',
    (tester) async {
      final repository = InMemoryPostsRepository();
      addTearDown(repository.dispose);
      final catalog = LocationCatalog(const [
        CampusLocation(id: 'server-location', name: 'Florida'),
        CampusLocation(id: 'server-location', name: ' FLORIDA '),
      ]);
      await openForm(tester, repository, catalog: catalog);
      final field = tester.widget<PostLocationField>(
        find.byType(PostLocationField),
      );
      expect(field.locationOptions, ['Florida']);
      expect(field.locationsAreTemporary, isFalse);
      field.onLocationChanged('Colombia');
      await tester.pumpAndSettle();
      expect(
        tester.widget<PostLocationField>(find.byType(PostLocationField)).value,
        isNull,
      );
      await fill(tester, withLocation: false);
      await tapKey(tester, 'publish-post');
      expect(repository.posts, isEmpty);
      await selectLocation(tester, 'Florida');
      await tapKey(tester, 'publish-post');
      expect(repository.posts.single.location, 'Florida');
    },
  );

  testWidgets(
    'Empty location list disables selection and never falls back to text entry',
    (tester) async {
      final form = GlobalKey<FormState>();
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: form,
                child: PostLocationField(
                  value: null,
                  locationOptions: const [],
                  onLocationChanged: (value) => selected = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(locationField())
            .onChanged,
        isNull,
      );
      expect(
        find.descendant(
          of: find.byType(PostLocationField),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      expect(
        find.text(
          'Konum listesi henüz hazır değil. Liste hazır olduğunda ilan oluşturabilirsiniz.',
        ),
        findsOneWidget,
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(
        tester.state<FormFieldState<String>>(locationField()).errorText,
        'Konum listesi henüz hazır değil.',
      );
      expect(selected, isNull);
    },
  );

  testWidgets('Reference composition fits without layout errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(487, 2300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = InMemoryPostsRepository();
    addTearDown(repository.dispose);
    const captureKey = ValueKey('create-post-capture');
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          theme: AppTheme.light,
          home: CreatePostScreen(repository: repository, user: sampleHomeUser),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final succeeds in [false, true]) {
    testWidgets(
      'Pending publication ignores completion after disposal: $succeeds',
      (tester) async {
        final repository = PendingRepository();
        addTearDown(repository.dispose);
        await openForm(tester, repository);
        await fill(tester);
        await reveal(tester, 'publish-post');
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('publish-post')))
            .onPressed!();
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        if (succeeds) {
          repository.pending.complete();
        } else {
          repository.pending.completeError(StateError('late failure'));
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(repository.posts.length, succeeds ? 1 : 0);
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('Form fits 320px with keyboard and text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = InMemoryPostsRepository();
      addTearDown(repository.dispose);
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
          home: CreatePostScreen(
            repository: repository,
            user: const UserProfile(
              firstName: 'Rümeysa',
              university: 'Sivas Cumhuriyet Üniversitesi',
              department: 'Elektrik-Elektronik Mühendisliği',
              campus: 'Cumhuriyet Kampüsü',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final nav = tester.getRect(find.byType(HomeBottomNavigation));
      await selectDepartment(tester, Departments.computerEngineering);
      await selectCourse(tester, 'Python Programlama');
      await enter(tester, 'post-description', 'Çok satırlı açıklama');
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await reveal(tester, 'post-location-option');
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await selectLocation(tester, 'Espressolab');
      await reveal(tester, 'offer-2');
      expect(find.text('Ders Karşılığı'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Ders Karşılığı')).dy -
            tester.getBottomLeft(find.byType(PostLocationField)).dy,
        closeTo(24, 1),
      );
      expect(find.byKey(const ValueKey('map-select')), findsNothing);
      expect(find.byIcon(Icons.map_outlined), findsNothing);
      await tester.tap(find.byKey(const ValueKey('offer-2')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Semantics>(
              find
                  .ancestor(
                    of: find.byKey(const ValueKey('offer-2')),
                    matching: find.byType(Semantics),
                  )
                  .first,
            )
            .properties
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await reveal(tester, 'publish-post');
      expect(tester.getRect(find.byType(HomeBottomNavigation)), nav);
      expect(tester.takeException(), isNull);
    });
  }
}
