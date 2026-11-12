import '../../features/applications/models/application.dart';
import '../../features/notifications/models/study_notification.dart';
import 'home_preview_data.dart';

List<StudyNotification> previewNotifications(List<Application> applications) {
  final now = DateTime.now();
  StudyNotification item({
    required NotificationKind kind,
    required NotificationTarget target,
    required String title,
    required String description,
    required Duration age,
    String? applicationId,
  }) => StudyNotification(
    id: 'mock-notification-${kind.name}',
    recipientId: sampleHomeUser.postsOwnerId,
    kind: kind,
    title: title,
    description: description,
    createdAt: now.subtract(age),
    target: target,
    targetId:
        applicationId == null
            ? null
            : applications.firstWhere((item) => item.id == applicationId).id,
  );

  return [
    item(
      kind: NotificationKind.newApplication,
      target: NotificationTarget.incomingApplication,
      title: 'Yeni Başvuru',
      description: 'Algoritma etüdü ilanına bir başvuru geldi.',
      age: const Duration(minutes: 5),
      applicationId: 'mock-incoming-1',
    ),
    item(
      kind: NotificationKind.lessonConfirmation,
      target: NotificationTarget.outgoingApplication,
      title: 'Ders Onayı Bekleniyor',
      description: 'Örnek ders için tamamlanma onayın bekleniyor.',
      age: const Duration(minutes: 45),
      applicationId: 'mock-confirmable-lesson',
    ),
    item(
      kind: NotificationKind.newMessage,
      target: NotificationTarget.conversation,
      title: 'Yeni Mesaj',
      description: 'Örnek mesaj bildirimi.',
      age: const Duration(hours: 2),
    ),
    item(
      kind: NotificationKind.applicationAccepted,
      target: NotificationTarget.outgoingApplication,
      title: 'Başvuru Kabul Edildi',
      description: 'Python dersi başvurun kabul edildi.',
      age: const Duration(days: 2, hours: 1),
      applicationId: 'mock-completed-outgoing',
    ),
    item(
      kind: NotificationKind.applicationRejected,
      target: NotificationTarget.outgoingApplication,
      title: 'Başvuru Reddedildi',
      description: 'Veri Yapıları dersine yaptığın başvuru reddedildi.',
      age: const Duration(days: 3, hours: 1),
      applicationId: 'mock-preview-rejected-request',
    ),
  ];
}
