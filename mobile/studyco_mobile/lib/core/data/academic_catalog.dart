import '../../features/posts/data/department_courses.dart';
import 'departments.dart';

String academicKey(String value) {
  var key = value.trim().replaceAll('İ', 'i').toLowerCase();
  const letters = {
    'ı': 'i',
    'ş': 's',
    'ğ': 'g',
    'ü': 'u',
    'ö': 'o',
    'ç': 'c',
    '\u0307': '',
  };
  for (final entry in letters.entries) {
    key = key.replaceAll(entry.key, entry.value);
  }
  return key.replaceAll(RegExp(r'\s+'), ' ');
}

/// Courses belong to this department, independently of their display titles.
/// id and course.id carry real server IDs when supplied; local IDs remain null.
class AcademicDepartment {
  AcademicDepartment({
    required this.name,
    this.id,
    Iterable<DepartmentCourse> courses = const [],
  }) : courses = List.unmodifiable(courses);
  final String name;
  final String? id;
  final List<DepartmentCourse> courses;
}

/// One immutable snapshot. Supplying a catalog replaces all temporary data.
class AcademicCatalog {
  factory AcademicCatalog(
    Iterable<AcademicDepartment> departments, {
    bool isTemporary = false,
  }) {
    final names = <String>{};
    final ids = <String>{};
    final result = <AcademicDepartment>[];
    for (final department in departments) {
      final key = academicKey(department.name);
      if (key.isEmpty ||
          names.contains(key) ||
          (department.id != null && ids.contains(department.id))) {
        continue;
      }
      names.add(key);
      if (department.id != null) ids.add(department.id!);
      final courseNames = <String>{};
      final courseIds = <String>{};
      final courses = <DepartmentCourse>[];
      for (final course in department.courses) {
        final titleKey = academicKey(course.title);
        // Other is a UI action, never a database course or an ID.
        if (course.isOther ||
            titleKey.isEmpty ||
            titleKey == academicKey('Diğer') ||
            courseNames.contains(titleKey) ||
            (course.id != null && courseIds.contains(course.id))) {
          continue;
        }
        courseNames.add(titleKey);
        if (course.id != null) courseIds.add(course.id!);
        courses.add(
          DepartmentCourse(
            title: course.title.trim(),
            subject: course.subject,
            id: course.id,
          ),
        );
      }
      result.add(
        AcademicDepartment(
          name: department.name.trim(),
          id: department.id,
          courses: courses,
        ),
      );
    }
    return AcademicCatalog._(List.unmodifiable(result), isTemporary);
  }
  const AcademicCatalog._(this.departments, this.isTemporary);
  final List<AcademicDepartment> departments;
  final bool isTemporary;

  /// The only temporary source; no real UUIDs are available here.
  static final temporary = AcademicCatalog([
    for (final name in Departments.values)
      AcademicDepartment(
        name: name,
        courses: DepartmentCourses.byDepartment[name] ?? const [],
      ),
  ], isTemporary: true);

  List<String> get departmentNames =>
      List.unmodifiable(departments.map((entry) => entry.name));

  AcademicDepartment? findDepartment(String? name) {
    if (name == null) return null;
    for (final department in departments) {
      if (academicKey(department.name) == academicKey(name)) return department;
    }
    return null;
  }

  List<DepartmentCourse> coursesFor(
    String? department, {
    bool includeOther = false,
  }) {
    final entry = findDepartment(department);
    if (entry == null) return const [];
    return List.unmodifiable([
      ...entry.courses,
      if (includeOther) DepartmentCourses.other,
    ]);
  }
}
