import '../../../core/constants/app_university.dart';

class UserProfile {
  const UserProfile({
    required this.firstName,
    this.id,
    this.university = studyCoUniversityName,
    required this.department,
    required this.campus,
    this.unreadMessages = 0,
    this.unreadNotifications = 0,
  });
  final String firstName;
  final String? id;
  static final _sessionIds = Expando<String>();
  static int _sequence = 0;

  /// Local fallback only; API integration must supply the authenticated user ID.
  String get postsOwnerId =>
      id ?? (_sessionIds[this] ??= 'session-user-${_sequence++}');
  // Legacy display value used by Home and Create Post. No backend field is
  // required; Profile uses the app constant independently of this value.
  final String university;
  final String department;
  final String campus;
  final int unreadMessages;
  final int unreadNotifications;
}
