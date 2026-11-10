import '../../core/data/academic_catalog.dart';
import '../../core/data/departments.dart';
import '../../features/profile/models/user_profile.dart';
import '../../features/posts/models/post.dart';
import '../../features/applications/models/application.dart';

const previewTeacherId = 'mock-preview-teacher';

/// Sample identity and badge counts; not an authenticated session.
const sampleHomeUser = UserProfile(
  id: 'mock-preview-student',
  firstName: 'Rümeysa',
  lastName: 'Örnek',
  phone: '0500 000 00 00',
  email: 'rumeysa@example.test',
  departmentId: 'mock-department-computer-engineering',
  university: 'Sivas Cumhuriyet Ünv.',
  department: Departments.computerEngineering,
  campus: 'Cumhuriyet Kampüs',
  unreadMessages: 2,
);

/// Explicit IDs used only by the preview profile repository.
AcademicCatalog previewProfileCatalog() => AcademicCatalog([
  AcademicDepartment(
    id: 'mock-department-computer-engineering',
    name: Departments.computerEngineering,
  ),
  AcademicDepartment(
    id: 'mock-department-software-engineering',
    name: Departments.softwareEngineering,
  ),
  AcademicDepartment(id: 'mock-department-medicine', name: 'Tıp'),
], isTemporary: true);

/// Debug-only composition fixture. IDs are explicit local mock IDs, not names
/// or authenticated server identities. Refreshed relative to the preview launch.
Post previewApplicationPost({DateTime? now}) {
  final today = now ?? DateTime.now();
  final start = DateTime(today.year, today.month, today.day + 2, 14);
  return Post(
    id: 'mock-preview-open-post',
    authorId: previewTeacherId,
    authorName: 'Deniz (örnek kullanıcı)',
    title: 'Python Etüdü (Örnek İlan)',
    topic: 'Fonksiyonlar ve döngüler',
    department: 'Bilgisayar Mühendisliği',
    description:
        'Fonksiyonlar ve döngüler üzerine örneklerle pratik yapacağız.',
    createdAt: today.toUtc(),
    startsAt: start,
    endsAt: start.add(const Duration(hours: 1)),
    location: 'Espressolab',
    type: PostType.tutoring,
    subject: PostSubject.coding,
    offer: PostOffer.free,
  );
}

/// Incoming demo data is instantiated only by the debug HOME_PREVIEW host.
Post previewIncomingPost({DateTime? now}) {
  final today = now ?? DateTime.now();
  final start = DateTime(today.year, today.month, today.day + 3, 16);
  return Post(
    id: 'mock-preview-owned-post',
    authorId: sampleHomeUser.postsOwnerId,
    authorName: sampleHomeUser.firstName,
    title: 'Algoritma Etüdü (Örnek İlan)',
    topic: 'Arama ve sıralama algoritmaları',
    description: 'Örnek sorular üzerinden birlikte pratik yapacağız.',
    department: 'Bilgisayar Mühendisliği',
    createdAt: today.toUtc().subtract(const Duration(minutes: 1)),
    startsAt: start,
    endsAt: start.add(const Duration(hours: 1)),
    location: 'Study',
    type: PostType.tutoring,
    subject: PostSubject.coding,
    offer: PostOffer.free,
  );
}

List<Application> previewIncomingApplications(Post post) => [
  for (var i = 1; i <= 3; i++)
    Application(
      id: 'mock-incoming-$i',
      postId: post.id,
      applicantId: 'mock-student-$i',
      teacherId: post.authorId,
      status: ApplicationStatus.pending,
      applicant: ApplicationPerson(
        id: 'mock-student-$i',
        firstName: ['Ece (örnek)', 'Can (örnek)', 'Aslı (örnek)'][i - 1],
      ),
      createdAt: post.createdAt,
      agreedTokenAmount: 0,
      listing: ApplicationListing(
        id: post.id,
        topic: post.topic,
        startAt: post.startsAt,
        endAt: post.endsAt,
        tokenPrice: 0,
      ),
    ),
];

/// Explicit completed fixtures, never inferred from the lesson date.
List<Application> previewCompletedApplications() => [
  for (final incoming in [false, true])
    Application(
      id: incoming ? 'mock-completed-incoming' : 'mock-completed-outgoing',
      postId:
          incoming
              ? 'mock-completed-owned-post'
              : 'mock-completed-foreign-post',
      applicantId:
          incoming ? 'mock-completed-student' : sampleHomeUser.postsOwnerId,
      teacherId: incoming ? sampleHomeUser.postsOwnerId : previewTeacherId,
      applicant: ApplicationPerson(
        id: incoming ? 'mock-completed-student' : sampleHomeUser.postsOwnerId,
        firstName: incoming ? 'Ece (örnek)' : sampleHomeUser.firstName,
      ),
      teacher: ApplicationPerson(
        id: incoming ? sampleHomeUser.postsOwnerId : previewTeacherId,
        firstName: incoming ? sampleHomeUser.firstName : 'Deniz (örnek)',
      ),
      status: ApplicationStatus.accepted,
      completionStatus: 'COMPLETED',
      listing: ApplicationListing(
        id:
            incoming
                ? 'mock-completed-owned-post'
                : 'mock-completed-foreign-post',
        topic: 'Tamamlanmış Python Dersi (Örnek)',
        startAt: DateTime.now().subtract(const Duration(days: 2)),
        endAt: DateTime.now().subtract(const Duration(days: 2, hours: -1)),
        tokenPrice: 0,
      ),
      agreedTokenAmount: 0,
    ),
];

const previewCompletionTeacher = UserProfile(
  id: previewTeacherId,
  firstName: 'Deniz (örnek ilan sahibi)',
  department: 'Bilgisayar Mühendisliği',
  campus: 'Cumhuriyet Kampüs',
);

Application previewConfirmableApplication({DateTime? now}) {
  final end = (now ?? DateTime.now()).toUtc().subtract(
    const Duration(hours: 1),
  );
  const postId = 'mock-confirmable-post';
  return Application(
    id: 'mock-confirmable-lesson',
    postId: postId,
    applicantId: sampleHomeUser.postsOwnerId,
    teacherId: previewCompletionTeacher.postsOwnerId,
    applicant: ApplicationPerson(
      id: sampleHomeUser.postsOwnerId,
      firstName: sampleHomeUser.firstName,
    ),
    teacher: ApplicationPerson(
      id: previewCompletionTeacher.postsOwnerId,
      firstName: previewCompletionTeacher.firstName,
    ),
    status: ApplicationStatus.accepted,
    completionStatus: LessonCompletionStatus.awaitingConfirmation.apiValue,
    confirmationDeadlineAt: end.add(const Duration(hours: 24)),
    listing: ApplicationListing(
      id: postId,
      topic: 'Ders Tamamlama (Örnek)',
      startAt: end.subtract(const Duration(hours: 1)),
      endAt: end,
      tokenPrice: 0,
    ),
  );
}

Application previewRejectedApplication() {
  const postId = 'mock-preview-rejected-lesson';
  final start = DateTime.now().subtract(const Duration(days: 3));
  return Application(
    id: 'mock-preview-rejected-request',
    postId: postId,
    applicantId: sampleHomeUser.postsOwnerId,
    teacherId: previewTeacherId,
    status: ApplicationStatus.rejected,
    listing: ApplicationListing(
      id: postId,
      topic: 'Veri Yapıları (Örnek)',
      startAt: start,
      endAt: start.add(const Duration(hours: 1)),
    ),
  );
}
