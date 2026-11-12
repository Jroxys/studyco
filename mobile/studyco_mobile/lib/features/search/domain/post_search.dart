import '../../../core/data/academic_catalog.dart';
import '../../posts/models/post.dart';
import '../../posts/domain/location_catalog.dart';

enum CoffeeFilter {
  all,
  free,
  one,
  two,
  three;

  int? get maxPrice => switch (this) {
    all => null,
    free => 0,
    one => 1,
    two => 2,
    three => 3,
  };
}

/// Shared normalization for queries, course identity and Turkish casing.
String normalizeSearch(String value) {
  var result =
      value.trim().replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  const replacements = {
    'ı': 'i',
    'ş': 's',
    'ğ': 'g',
    'ü': 'u',
    'ö': 'o',
    'ç': 'c',
    '\u0307': '',
  };
  for (final entry in replacements.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result.replaceAll(RegExp(r'\s+'), ' ');
}

class PostSearch {
  const PostSearch({
    this.query = '',
    this.department,
    this.course,
    this.coffee = CoffeeFilter.all,
    this.location,
  });

  final String query;
  final String? department;
  final String? course;
  final CoffeeFilter coffee;
  // Temporary catalog names; API integration must resolve departmentId,
  // courseId and locationId from real catalogs, without inventing UUIDs.
  final String? location;

  static List<String> courses(
    Iterable<Post> posts,
    String? department, {
    AcademicCatalog? catalog,
  }) {
    final source = catalog ?? AcademicCatalog.temporary;
    final names = <String, String>{};
    void add(String title) {
      final key = normalizeSearch(title);
      if (key.isNotEmpty && key != normalizeSearch('Diğer')) {
        names.putIfAbsent(key, () => title.trim());
      }
    }

    for (final section
        in department == null ? source.departmentNames : [department]) {
      for (final course in source.coursesFor(section)) {
        if (!course.isOther) add(course.title);
      }
    }
    // Preserve local manual/legacy lessons only with the temporary source.
    // A supplied server catalog is authoritative, never extended with fixtures.
    if (source.isTemporary) {
      for (final post in posts) {
        if (department == null || post.department == department) {
          add(post.title);
        }
      }
    }
    return names.values.toList()
      ..sort((a, b) => normalizeSearch(a).compareTo(normalizeSearch(b)));
  }

  List<Post> apply(Iterable<Post> posts) {
    final terms = normalizeSearch(
      query,
    ).split(' ').where((term) => term.isNotEmpty);
    final result =
        posts.where((post) {
          if (department != null && post.department != department) return false;
          if (course != null &&
              normalizeSearch(post.title) != normalizeSearch(course!)) {
            return false;
          }
          if (location != null &&
              locationKey(post.location) != locationKey(location!)) {
            return false;
          }
          final price = post.offer == PostOffer.free ? 0 : post.coffeeCount;
          final maxPrice = coffee.maxPrice;
          if (maxPrice != null && price > maxPrice) return false;
          final text = normalizeSearch(post.topic ?? '');
          return terms.every(text.contains);
        }).toList();
    result.sort((a, b) {
      final date = a.startsAt.compareTo(b.startsAt);
      return date == 0 ? a.id.compareTo(b.id) : date;
    });
    return result;
  }
}
