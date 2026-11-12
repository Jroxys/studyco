import '../domain/notifications_repository.dart';
import '../models/study_notification.dart';

class InMemoryNotificationsRepository extends NotificationsRepository {
  InMemoryNotificationsRepository({
    required this.userId,
    Iterable<StudyNotification> initialNotifications = const [],
  }) : _items = {
         for (final item in initialNotifications)
           if (userId.trim().isNotEmpty && item.recipientId == userId)
             item.id: item,
       };

  @override
  final String userId;
  final Map<String, StudyNotification> _items;

  @override
  List<StudyNotification> get notifications => List.unmodifiable(_items.values);

  @override
  int get unreadCount => _items.values.where((item) => !item.isRead).length;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> markRead(String notificationId) async {
    final item = _items[notificationId];
    if (item == null) {
      throw const NotificationFailure(
        'Bu bildirim hesabına ait değil veya artık görüntülenemiyor.',
      );
    }
    if (item.isRead) return;
    _items[notificationId] = item.asRead();
    notifyListeners();
  }

  @override
  Future<void> markAllRead() async {
    if (unreadCount == 0) return;
    _items.updateAll((_, item) => item.isRead ? item : item.asRead());
    notifyListeners();
  }

  @override
  void dispose() {
    _items.clear();
    super.dispose();
  }
}
