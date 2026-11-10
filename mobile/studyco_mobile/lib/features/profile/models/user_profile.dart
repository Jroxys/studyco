import '../../../core/constants/app_university.dart';

class UserProfile {
  const UserProfile({
    required this.firstName,
    this.id,
    this.lastName,
    this.phone,
    this.email,
    this.departmentId,
    this.university = studyCoUniversityName,
    required this.department,
    required this.campus,
    this.unreadMessages = 0,
  });
  final String firstName;
  final String? id;
  final String? lastName;
  final String? phone;
  final String? email;
  final String? departmentId;
  String get fullName => [firstName, lastName]
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(' ');

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
}
