import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/core/data/academic_catalog.dart';
import 'package:studyco_mobile/core/data/departments.dart';
import 'package:studyco_mobile/core/widgets/academic_catalog_scope.dart';
import 'package:studyco_mobile/features/auth/screens/register_screen.dart';
import 'package:studyco_mobile/features/posts/data/department_courses.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'package:studyco_mobile/features/posts/models/post.dart';
import 'package:studyco_mobile/features/search/domain/post_search.dart';
import 'package:studyco_mobile/features/search/screens/search_screen.dart';
import 'create_post_test.dart' as create;
import 'search_test.dart' as search;

AcademicCatalog remoteCatalog() => AcademicCatalog([
  AcademicDepartment(
    id: 'server-department-a',
    name: 'Tıp',
    courses: const [
      DepartmentCourse(
        id: 'server-course-a',
        title: 'Ortak Ders',
        subject: PostSubject.general,
      ),
      DepartmentCourse(
        id: 'server-course-b',
        title: 'Klinik Ders',
        subject: PostSubject.general,
      ),
      DepartmentCourse(
        id: 'duplicate-name',
        title: ' ORTAK DERS ',
        subject: PostSubject.general,
      ),
    ],
  ),
  AcademicDepartment(id: 'duplicate-department', name: ' TIP '),
  AcademicDepartment(
    id: 'server-department-b',
    name: 'Hukuk',
    courses: const [
      DepartmentCourse(
        id: 'server-course-c',
        title: 'Ortak Ders',
        subject: PostSubject.general,
      ),
      DepartmentCourse(
        id: 'server-course-d',
        title: 'Usul Ders',
        subject: PostSubject.general,
      ),
    ],
  ),
]);

List<T?> menuValues<T>(WidgetTester tester, Finder field) =>
    tester
        .widget<DropdownButton<T>>(
          find.descendant(of: field, matching: find.byType(DropdownButton<T>)),
        )
        .items!
        .map((item) => item.value)
        .toList();

void main() {
  test(
    'Catalog keeps real IDs and department relationships, removes duplicates and keeps Other local',
    () {
      final catalog = remoteCatalog();
      expect(catalog.departmentNames, ['Tıp', 'Hukuk']);
      expect(catalog.findDepartment('TIP')!.id, 'server-department-a');
      expect(catalog.coursesFor('Tıp').map((course) => course.title), [
        'Ortak Ders',
        'Klinik Ders',
      ]);
      expect(catalog.coursesFor('Tıp').first.id, 'server-course-a');
      expect(catalog.coursesFor('Hukuk').first.id, 'server-course-c');
      expect(
        catalog.coursesFor('Tıp', includeOther: true).last.isOther,
        isTrue,
      );
      expect(catalog.coursesFor('Tıp', includeOther: true).last.id, isNull);
      expect(
        catalog.departments
            .expand((department) => department.courses)
            .any((course) => course.isOther),
        isFalse,
      );
      expect(AcademicCatalog.temporary.departmentNames, Departments.values);
      expect(
        AcademicCatalog.temporary.departments.every(
          (department) =>
              department.id == null &&
              department.courses.every((course) => course.id == null),
        ),
        isTrue,
      );
      expect(() => catalog.departments.clear(), throwsUnsupportedError);
      expect(
        () => catalog.departments.first.courses.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'Empty and supplied catalogs exclude temporary and legacy course suggestions',
    () {
      final catalog = remoteCatalog();
      final posts = [search.listing(0, title: 'Geçici Manuel Ders')];
      expect(PostSearch.courses(posts, null, catalog: catalog), [
        'Klinik Ders',
        'Ortak Ders',
        'Usul Ders',
      ]);
      final empty = AcademicCatalog(const []);
      expect(empty.departmentNames, isEmpty);
      expect(empty.coursesFor('Tıp', includeOther: true), isEmpty);
      expect(PostSearch.courses(posts, null, catalog: empty), isEmpty);
      final duplicateIds = AcademicCatalog([
        AcademicDepartment(
          id: 'same',
          name: 'Tıp',
          courses: const [
            DepartmentCourse(
              id: 'same-course',
              title: 'Bir',
              subject: PostSubject.general,
            ),
            DepartmentCourse(
              id: 'same-course',
              title: 'İki',
              subject: PostSubject.general,
            ),
            DepartmentCourses.other,
          ],
        ),
        AcademicDepartment(id: 'same', name: 'Hukuk'),
      ]);
      expect(duplicateIds.departmentNames, ['Tıp']);
      expect(duplicateIds.coursesFor('Tıp').map((course) => course.title), [
        'Bir',
      ]);
    },
  );

  testWidgets(
    'Search Create and Register share supplied catalog and clear old selections',
    (tester) async {
      final repository = InMemoryPostsRepository(
        initialPosts: [
          search.listing(0, title: 'Ortak Ders'),
          search.listing(1, title: 'Ortak Ders', department: 'Hukuk'),
          search.listing(2, title: 'Geçici Manuel Ders'),
        ],
      );
      final source = ValueNotifier(remoteCatalog());
      addTearDown(repository.dispose);
      addTearDown(source.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder:
              (_, child) => ValueListenableBuilder<AcademicCatalog>(
                valueListenable: source,
                builder:
                    (_, catalog, _) =>
                        AcademicCatalogScope(catalog: catalog, child: child!),
              ),
          home: SearchScreen(repository: repository, user: sampleHomeUser),
        ),
      );
      await tester.pumpAndSettle();
      expect(menuValues<String?>(tester, search.menu('Bölüm')), [
        null,
        'Tıp',
        'Hukuk',
      ]);
      expect(menuValues<String?>(tester, search.menu('Ders')), [
        null,
        'Klinik Ders',
        'Ortak Ders',
        'Usul Ders',
      ]);
      await search.select<String?>(tester, 'Bölüm', 'Tıp');
      await search.select<String?>(tester, 'Ders', 'Ortak Ders');
      expect(find.text('1 ilan bulundu'), findsOneWidget);
      await search.select<String?>(tester, 'Bölüm', 'Hukuk');
      expect(
        tester.state<FormFieldState<String?>>(search.menu('Ders')).value,
        isNull,
      );
      expect(menuValues<String?>(tester, search.menu('Ders')), [
        null,
        'Ortak Ders',
        'Usul Ders',
      ]);

      await tester.tap(find.byKey(const ValueKey('home-nav-1')));
      await tester.pumpAndSettle();
      expect(
        menuValues<String>(
          tester,
          find.byKey(const ValueKey('post-department')),
        ),
        ['Tıp', 'Hukuk'],
      );
      await create.selectDepartment(tester, 'Tıp');
      expect(
        menuValues<DepartmentCourse>(
          tester,
          create.courseField(),
        ).map((course) => course!.title),
        ['Ortak Ders', 'Klinik Ders', 'Diğer'],
      );
      await create.selectCourse(tester, 'Ortak Ders');
      expect(
        tester
            .state<FormFieldState<DepartmentCourse>>(create.courseField())
            .value!
            .id,
        'server-course-a',
      );
      await create.selectDepartment(tester, 'Hukuk');
      expect(
        tester
            .state<FormFieldState<DepartmentCourse>>(create.courseField())
            .value,
        isNull,
      );
      await create.selectCourse(tester, 'Diğer');
      await create.enter(tester, 'post-manual-title', 'Elle girilen ders');
      await create.selectDepartment(tester, 'Tıp');
      expect(find.byKey(const ValueKey('post-manual-title')), findsNothing);
      await create.selectCourse(tester, 'Diğer');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('post-manual-title')),
            )
            .controller!
            .text,
        isEmpty,
      );
      // Replacing an active source resets both linked selections without stale values.
      source.value = AcademicCatalog(const []);
      await tester.pumpAndSettle();
      expect(
        menuValues<String>(
          tester,
          find.byKey(const ValueKey('post-department')),
        ),
        isEmpty,
      );
      expect(
        tester
            .state<FormFieldState<DepartmentCourse>>(create.courseField())
            .value,
        isNull,
      );
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(menuValues<String?>(tester, search.menu('Bölüm')), [null]);
      expect(menuValues<String?>(tester, search.menu('Ders')), [null]);
      expect(find.text('3 ilan bulundu'), findsOneWidget);

      source.value = remoteCatalog();
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SearchScreen));
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));
      await tester.pumpAndSettle();
      final registration = find.byType(DropdownButtonFormField<String>);
      expect(menuValues<String>(tester, registration), ['Tıp', 'Hukuk']);
      await tester.ensureVisible(registration);
      await tester.tap(registration);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tıp').last);
      await tester.pumpAndSettle();
      expect(tester.state<FormFieldState<String>>(registration).value, 'Tıp');
      source.value = AcademicCatalog(const []);
      await tester.pumpAndSettle();
      expect(menuValues<String>(tester, registration), isEmpty);
      expect(tester.state<FormFieldState<String>>(registration).value, isNull);
      expect(
        tester.widget<DropdownButtonFormField<String>>(registration).onChanged,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final manual in [false, true]) {
    testWidgets(
      'Supplied catalog publishes correct local department and lesson (manual: $manual)',
      (tester) async {
        final repository = InMemoryPostsRepository();
        addTearDown(repository.dispose);
        await create.openForm(
          tester,
          repository,
          academicCatalog: remoteCatalog(),
        );
        await create.fill(
          tester,
          department: 'Tıp',
          course: manual ? 'Diğer' : 'Klinik Ders',
        );
        if (manual) {
          await create.enter(tester, 'post-manual-title', ' Özel Ders Adı ');
        }
        await create.tapKey(tester, 'publish-post');
        expect(repository.posts.single.department, 'Tıp');
        expect(
          repository.posts.single.title,
          manual ? 'Özel Ders Adı' : 'Klinik Ders',
        );
      },
    );
  }
}
