import 'package:flutter/foundation.dart';
import '../models/study_notification.dart';

class NotificationFailure implements Exception {
  const NotificationFailure(this.message);
  final String message;
}

/// One authenticated account. Mutations publish confirmed changes and notify
/// listeners. Failures preserve the last confirmed snapshot.
abstract class NotificationsRepository extends ChangeNotifier {
  String get userId;
  List<StudyNotification> get notifications;
  int get unreadCount;
  Future<void> refresh();
  Future<void> markRead(String notificationId);
  Future<void> markAllRead();
}
