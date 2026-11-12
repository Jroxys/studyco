import '../../applications/domain/applications_repository.dart';
import '../../applications/models/application.dart';
import '../domain/notifications_repository.dart';
import '../models/study_notification.dart';

/// The backend has no notifications endpoint yet, so notifications are derived
/// from the user's lesson requests. Read state lives for this session only.
class RequestNotificationsRepository extends NotificationsRepository {
  RequestNotificationsRepository({
    required this.userId,
    required this.applications,
  });

  @override
  final String userId;
  final ApplicationsRepository applications;
  final Set<String> _read = {};
  List<StudyNotification> _items = const [];

  @override
  List<StudyNotification> get notifications => _items;

  @override
  int get unreadCount => _items.where((item) => !item.isRead).length;

  @override
  Future<void> refresh() async {
    try {
      await Future.wait([
        applications.refresh(applicantId: userId),
        applications.refreshIncoming(ownerId: userId),
      ]);
    } on ApplicationFailure catch (failure) {
      throw NotificationFailure(failure.message);
    }
    _rebuild();
  }

  void _rebuild() {
    final items = <StudyNotification>[
      for (final item in applications.forOwner(userId)) ..._incoming(item),
      for (final item in applications.forApplicant(userId)) ..._outgoing(item),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _items = List.unmodifiable(
      items.map((item) => _read.contains(item.id) ? item.asRead() : item),
    );
    notifyListeners();
  }

  Iterable<StudyNotification> _incoming(Application item) sync* {
    final who = item.applicant?.displayName ?? 'Bir öğrenci';
    final topic = item.listing?.topic ?? 'ilanın';
    if (item.isPending) {
      yield _make(
        'incoming-${item.id}',
        NotificationKind.newApplication,
        'Yeni başvuru',
        '$who "$topic" ilanına başvurdu.',
        item.createdAt,
        NotificationTarget.incomingApplication,
        item.id,
      );
    }
    if (item.lessonCompletionStatus ==
            LessonCompletionStatus.awaitingConfirmation &&
        item.teacherCompletedAt == null) {
      yield _confirmation(item, NotificationTarget.incomingApplication);
    }
  }

  Iterable<StudyNotification> _outgoing(Application item) sync* {
    final topic = item.listing?.topic ?? 'Başvurduğun ders';
    switch (item.status) {
      case ApplicationStatus.accepted:
        yield _make(
          'accepted-${item.id}',
          NotificationKind.applicationAccepted,
          'Başvurun kabul edildi',
          '"$topic" dersi için başvurun kabul edildi.',
          item.respondedAt ?? item.createdAt,
          NotificationTarget.outgoingApplication,
          item.id,
        );
      case ApplicationStatus.rejected:
        yield _make(
          'rejected-${item.id}',
          NotificationKind.applicationRejected,
          'Başvurun reddedildi',
          '"$topic" dersi için başvurun reddedildi.',
          item.respondedAt ?? item.createdAt,
          NotificationTarget.outgoingApplication,
          item.id,
        );
      default:
        break;
    }
    if (item.lessonCompletionStatus ==
            LessonCompletionStatus.awaitingConfirmation &&
        item.studentCompletedAt == null) {
      yield _confirmation(item, NotificationTarget.outgoingApplication);
    }
  }

  StudyNotification _confirmation(
    Application item,
    NotificationTarget target,
  ) => _make(
    'confirm-${item.id}',
    NotificationKind.lessonConfirmation,
    'Ders onayı bekleniyor',
    '"${item.listing?.topic ?? 'Ders'}" tamamlandıysa onay ver.',
    item.listing?.endAt ?? item.createdAt,
    target,
    item.id,
  );

  StudyNotification _make(
    String id,
    NotificationKind kind,
    String title,
    String description,
    DateTime? at,
    NotificationTarget target,
    String targetId,
  ) => StudyNotification(
    id: id,
    recipientId: userId,
    kind: kind,
    title: title,
    description: description,
    createdAt: at ?? DateTime.fromMillisecondsSinceEpoch(0),
    target: target,
    targetId: targetId,
  );

  @override
  Future<void> markRead(String notificationId) async {
    if (!_items.any((item) => item.id == notificationId)) {
      throw const NotificationFailure('Bu bildirim artık görüntülenemiyor.');
    }
    if (_read.add(notificationId)) _rebuild();
  }

  @override
  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    _read.addAll(_items.map((item) => item.id));
    _rebuild();
  }
}
