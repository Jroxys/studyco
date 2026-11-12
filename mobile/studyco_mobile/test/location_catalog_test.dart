import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/posts/data/campus_locations.dart';
import 'package:studyco_mobile/features/posts/data/sample_posts.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'package:studyco_mobile/features/posts/domain/location_catalog.dart';
import 'package:studyco_mobile/features/posts/widgets/location_catalog_scope.dart';
import 'package:studyco_mobile/features/posts/widgets/post_location_field.dart';
import 'package:studyco_mobile/features/search/screens/search_screen.dart';
import 'search_test.dart' as fixtures;

void main() {
  test('Catalog deduplicates names and IDs without inventing IDs', () {
    final catalog = LocationCatalog(const [
      CampusLocation(name: ' Merkez Kütüphane '),
      CampusLocation(name: 'MERKEZ KUTUPHANE'),
      CampusLocation(id: 'server-location', name: 'Moon Cafe'),
      CampusLocation(id: 'server-location', name: 'Coffee Lab'),
      CampusLocation(name: '   '),
    ]);
    expect(catalog.names, ['Merkez Kütüphane', 'Moon Cafe']);
    expect(catalog.findByName('MERKEZ KÜTÜPHANE')!.id, isNull);
    expect(catalog.findByName(' moon cafe ')!.id, 'server-location');
    expect(() => catalog.entries.clear(), throwsUnsupportedError);
    expect(
      CampusLocations.catalog.entries.every((entry) => entry.id == null),
      isTrue,
    );
  });

  test(
    'Temporary catalog matches the ten supplied seed names exactly once',
    () {
      expect(CampusLocations.catalog.names, [
        'Espressolab',
        'Florida',
        'Colombia',
        'Starbucks',
        'Study',
        'Nevada',
        'Loba',
        'Albert',
        'Nexq',
        'Arabica',
      ]);
      expect(
        CampusLocations.catalog.names.map(locationKey).toSet(),
        hasLength(10),
      );
      expect(
        CampusLocations.catalog.entries.every((entry) => entry.id == null),
        isTrue,
      );
      for (final post in samplePosts()) {
        expect(
          CampusLocations.catalog.findByName(post.location)?.name,
          post.location,
        );
      }
    },
  );

  testWidgets(
    'Search and Create share replacement catalog across routes without merging',
    (tester) async {
      final repository = InMemoryPostsRepository(
        initialPosts: [
          fixtures.listing(0, location: 'Colombia'),
          fixtures.listing(1, location: ' cOlOmBiA '),
          fixtures.listing(2, location: 'Florida'),
        ],
      );
      final source = ValueNotifier(CampusLocations.catalog);
      addTearDown(repository.dispose);
      addTearDown(source.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder:
              (_, child) => ValueListenableBuilder<LocationCatalog>(
                valueListenable: source,
                builder:
                    (_, catalog, _) =>
                        LocationCatalogScope(catalog: catalog, child: child!),
              ),
          home: SearchScreen(repository: repository, user: sampleHomeUser),
        ),
      );
      await tester.pumpAndSettle();
      List<String?> options() =>
          tester
              .widget<DropdownButton<String?>>(
                find.descendant(
                  of: fixtures.menu('Konum'),
                  matching: find.byType(DropdownButton<String?>),
                ),
              )
              .items!
              .map((entry) => entry.value)
              .toList();
      expect(options(), [null, ...CampusLocations.values]);
      await fixtures.select<String?>(tester, 'Konum', 'Colombia');
      expect(find.text('2 ilan bulundu'), findsOneWidget);

      source.value = LocationCatalog(const [
        CampusLocation(id: 'server-location', name: 'Florida'),
        CampusLocation(id: 'server-location', name: ' FLORIDA '),
      ]);
      await tester.pumpAndSettle();
      expect(options(), [null, 'Florida']);
      expect(
        tester.state<FormFieldState<String?>>(fixtures.menu('Konum')).value,
        isNull,
      );
      expect(find.text('3 ilan bulundu'), findsOneWidget);
      await fixtures.select<String?>(tester, 'Konum', 'Florida');
      expect(find.text('1 ilan bulundu'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-nav-1')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PostLocationField>(find.byType(PostLocationField))
            .locationOptions,
        ['Florida'],
      );
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(find.text('1 ilan bulundu'), findsOneWidget);

      source.value = LocationCatalog(const []);
      await tester.pumpAndSettle();
      expect(options(), [null]);
      expect(find.text('3 ilan bulundu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // The posts themselves keep their original display names.
      expect(repository.posts[1].location, ' cOlOmBiA ');
    },
  );
}
