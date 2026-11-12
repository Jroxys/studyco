import '../../features/posts/data/department_courses.dart';
import '../../features/posts/domain/location_catalog.dart';
import '../../features/posts/models/post.dart';
import '../api/api_client.dart';
import 'academic_catalog.dart';

/// Loads the server-owned departments, courses and locations.
class RemoteCatalog {
  const RemoteCatalog(this.api);
  final ApiClient api;

  /// Public endpoint, used by registration before an account exists.
  Future<AcademicCatalog> departmentsOnly() async {
    final departments = await _list('/departments', auth: false);
    return AcademicCatalog([
      for (final item in departments)
        AcademicDepartment(
          id: item['id'] as String,
          name: item['name'] as String,
        ),
    ]);
  }

  Future<AcademicCatalog> academic() async {
    final results = await Future.wait([
      _list('/departments', auth: false),
      _list('/courses'),
    ]);
    final byDepartment = <String, List<DepartmentCourse>>{};
    for (final course in results[1]) {
      final title = course['name'] as String;
      byDepartment
          .putIfAbsent(course['departmentId'] as String, () => [])
          .add(
            DepartmentCourse(
              id: course['id'] as String,
              title: title,
              subject: subjectFor(title),
            ),
          );
    }
    return AcademicCatalog([
      for (final item in results[0])
        AcademicDepartment(
          id: item['id'] as String,
          name: item['name'] as String,
          courses: byDepartment[item['id']] ?? const [],
        ),
    ]);
  }

  Future<LocationCatalog> locations() async => LocationCatalog([
    for (final item in await _list('/locations'))
      CampusLocation(id: item['id'] as String, name: item['name'] as String),
  ]);

  Future<List<Map<String, dynamic>>> _list(
    String path, {
    bool auth = true,
  }) async {
    final json = await api.get(path, auth: auth);
    if (json is! List) throw const FormatException('Liste bekleniyordu.');
    return json.cast<Map<String, dynamic>>();
  }
}

/// Display category for a course title; the backend has no subject field.
PostSubject subjectFor(String courseTitle) {
  final key = academicKey(courseTitle);
  const coding = [
    'program',
    'yazilim',
    'algoritma',
    'veri yapilari',
    'python',
    'java',
    'kodlama',
    'web',
    'mobil',
  ];
  const math = [
    'matematik',
    'calculus',
    'kalkulus',
    'analiz',
    'lineer',
    'dogrusal',
    'istatistik',
    'olasilik',
    'diferansiyel',
  ];
  if (coding.any(key.contains)) return PostSubject.coding;
  if (math.any(key.contains)) return PostSubject.mathematics;
  return PostSubject.general;
}
