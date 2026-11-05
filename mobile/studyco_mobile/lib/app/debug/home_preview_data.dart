import '../../features/profile/models/user_profile.dart';
import '../../features/posts/models/post.dart';
import '../../features/applications/models/application.dart';

const previewTeacherId = 'mock-preview-teacher';

/// Sample identity and badge counts; not an authenticated session.
const sampleHomeUser = UserProfile(
  id: 'mock-preview-student',
  firstName: 'Rümeysa',
  university: 'Sivas Cumhuriyet Ünv.',
  department: 'Bilgisayar Müh.',
  campus: 'Cumhuriyet Kampüs',
  unreadMessages: 2,
  unreadNotifications: 1,
);

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
