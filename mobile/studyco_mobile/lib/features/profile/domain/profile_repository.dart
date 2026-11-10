import 'package:flutter/foundation.dart';
import '../../../core/data/academic_catalog.dart';
import '../models/user_profile.dart';

class ProfileFailure implements Exception {
  const ProfileFailure(this.message);
  final String message;
}

/// Null fields are omitted. An empty phone means the user requested clearing it.
class ProfileChanges {
  const ProfileChanges({
    this.firstName,
    this.lastName,
    this.phone,
    this.departmentId,
  });
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? departmentId;

  bool get isEmpty =>
      firstName == null &&
      lastName == null &&
      phone == null &&
      departmentId == null;
}

/// Source for one authenticated account. Adapters publish only confirmed
/// snapshots and retain the last good snapshot on errors.
abstract class ProfileRepository extends ChangeNotifier {
  String? get userId;
  UserProfile? get current;
  Future<UserProfile> fetchProfile();
  Future<List<AcademicDepartment>> fetchDepartments();
  Future<UserProfile> updateProfile(ProfileChanges changes);
}
