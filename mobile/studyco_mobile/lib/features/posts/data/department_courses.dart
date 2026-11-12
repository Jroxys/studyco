import '../../../core/data/departments.dart';
import '../models/post.dart';

/// A local lesson choice, distinct from department and the free-text topic.
class DepartmentCourse {
  const DepartmentCourse({
    required this.title,
    required this.subject,
    this.isOther = false,
    this.id,
  }) : assert(!isOther || id == null);
  // Real courseId when supplied by the server; never a display name.
  final String? id;
  final String title;
  final PostSubject subject;
  final bool isOther;
}

/// Starter suggestions only, not an official university curriculum.
/// Add prepared courses here; forDepartment appends the manual option last.
abstract final class DepartmentCourses {
  static const other = DepartmentCourse(
    title: 'Diğer',
    subject: PostSubject.general,
    isOther: true,
  );
  static const byDepartment = <String, List<DepartmentCourse>>{
    Departments.computerEngineering: [
      DepartmentCourse(
        title: 'Python Programlama',
        subject: PostSubject.coding,
      ),
      DepartmentCourse(title: 'Veri Yapıları', subject: PostSubject.coding),
      DepartmentCourse(title: 'Algoritmalar', subject: PostSubject.coding),
      DepartmentCourse(title: 'Lineer Cebir', subject: PostSubject.mathematics),
    ],
    Departments.softwareEngineering: [
      DepartmentCourse(
        title: 'Programlama Temelleri',
        subject: PostSubject.coding,
      ),
      DepartmentCourse(title: 'Veri Yapıları', subject: PostSubject.coding),
      DepartmentCourse(
        title: 'Veritabanı Yönetimi',
        subject: PostSubject.coding,
      ),
      DepartmentCourse(
        title: 'Yazılım Mühendisliği',
        subject: PostSubject.coding,
      ),
    ],
    'Elektrik-Elektronik Mühendisliği': [
      DepartmentCourse(title: 'Devre Analizi', subject: PostSubject.general),
      DepartmentCourse(title: 'Elektronik', subject: PostSubject.general),
      DepartmentCourse(
        title: 'Elektromanyetik Alanlar',
        subject: PostSubject.general,
      ),
      DepartmentCourse(
        title: 'Sinyaller ve Sistemler',
        subject: PostSubject.general,
      ),
    ],
    'Makine Mühendisliği': [
      DepartmentCourse(title: 'Statik', subject: PostSubject.general),
      DepartmentCourse(title: 'Dinamik', subject: PostSubject.general),
      DepartmentCourse(title: 'Termodinamik', subject: PostSubject.general),
      DepartmentCourse(title: 'Mukavemet', subject: PostSubject.general),
    ],
    'İşletme': [
      DepartmentCourse(title: 'Genel Muhasebe', subject: PostSubject.general),
      DepartmentCourse(
        title: 'Pazarlama İlkeleri',
        subject: PostSubject.general,
      ),
      DepartmentCourse(title: 'Finansal Yönetim', subject: PostSubject.general),
      DepartmentCourse(
        title: 'Yönetim ve Organizasyon',
        subject: PostSubject.general,
      ),
    ],
    'İktisat': [
      DepartmentCourse(title: 'Mikroiktisat', subject: PostSubject.general),
      DepartmentCourse(title: 'Makroiktisat', subject: PostSubject.general),
      DepartmentCourse(title: 'Ekonometri', subject: PostSubject.general),
      DepartmentCourse(
        title: 'Uluslararası İktisat',
        subject: PostSubject.general,
      ),
    ],
    'Hukuk': [
      DepartmentCourse(title: 'Anayasa Hukuku', subject: PostSubject.general),
      DepartmentCourse(title: 'Medeni Hukuk', subject: PostSubject.general),
      DepartmentCourse(title: 'Ceza Hukuku', subject: PostSubject.general),
      DepartmentCourse(title: 'Borçlar Hukuku', subject: PostSubject.general),
    ],
    'Tıp': [
      DepartmentCourse(title: 'Anatomi', subject: PostSubject.general),
      DepartmentCourse(title: 'Fizyoloji', subject: PostSubject.general),
      DepartmentCourse(title: 'Tıbbi Biyokimya', subject: PostSubject.general),
      DepartmentCourse(title: 'Histoloji', subject: PostSubject.general),
    ],
    'Psikoloji': [
      DepartmentCourse(
        title: 'Psikolojiye Giriş',
        subject: PostSubject.general,
      ),
      DepartmentCourse(
        title: 'Gelişim Psikolojisi',
        subject: PostSubject.general,
      ),
      DepartmentCourse(title: 'Sosyal Psikoloji', subject: PostSubject.general),
      DepartmentCourse(
        title: 'Bilişsel Psikoloji',
        subject: PostSubject.general,
      ),
    ],
    // Broad academic suggestions for the uncategorized department choice.
    'Diğer': [
      DepartmentCourse(title: 'Akademik Yazım', subject: PostSubject.general),
      DepartmentCourse(
        title: 'Araştırma Yöntemleri',
        subject: PostSubject.general,
      ),
      DepartmentCourse(title: 'Etkili İletişim', subject: PostSubject.general),
    ],
  };

  static List<DepartmentCourse> forDepartment(String? department) {
    final prepared = byDepartment[department];
    return prepared == null
        ? const []
        : List.unmodifiable([...prepared, other]);
  }
}
