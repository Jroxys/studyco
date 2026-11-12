import '../../../core/api/api_client.dart';
import '../../../core/constants/app_university.dart';
import '../../../core/data/academic_catalog.dart';
import '../../../core/session/auth_session.dart';
import '../domain/profile_repository.dart';
import '../models/user_profile.dart';

/// `/api/v1/me` for the signed-in account.
class RemoteProfileRepository extends ProfileRepository {
  RemoteProfileRepository({
    required this.session,
    required this.academicCatalog,
  }) : _current = profileFor(session.user!, academicCatalog());

  final AuthSession session;
  final AcademicCatalog Function() academicCatalog;
  UserProfile _current;

  static UserProfile profileFor(AuthUser user, AcademicCatalog catalog) {
    final department =
        catalog.departments
            .where((item) => item.id == user.departmentId)
            .map((item) => item.name)
            .firstOrNull ??
        '';
    return UserProfile(
      id: user.id,
      firstName: user.firstName,
      lastName: user.lastName,
      phone: user.phone,
      email: user.email,
      departmentId: user.departmentId,
      department: department,
      campus: studyCoUniversityName,
    );
  }

  @override
  String? get userId => _current.id;

  @override
  UserProfile get current => _current;

  @override
  Future<UserProfile> fetchProfile() async {
    try {
      return _accept(await session.api.get('/me'));
    } catch (error) {
      throw ProfileFailure(
        apiErrorMessage(error, fallback: 'Profil yüklenemedi.'),
      );
    }
  }

  @override
  Future<List<AcademicDepartment>> fetchDepartments() async =>
      List.unmodifiable(
        academicCatalog().departments.where(
          (item) => item.id?.isNotEmpty == true,
        ),
      );

  @override
  Future<UserProfile> updateProfile(ProfileChanges changes) async {
    if (changes.isEmpty) return _current;
    final phone = changes.phone?.trim();
    if (phone != null && phone.isEmpty) {
      throw const ProfileFailure('Telefon numarası boş bırakılamaz.');
    }
    final body = <String, Object?>{
      if (changes.firstName != null) 'firstName': changes.firstName!.trim(),
      if (changes.lastName != null) 'lastName': changes.lastName!.trim(),
      if (phone != null) 'phone': phone,
      if (changes.departmentId != null) 'departmentId': changes.departmentId,
    };
    try {
      return _accept(await session.api.patch('/me', body: body));
    } catch (error) {
      throw ProfileFailure(
        apiErrorMessage(error, fallback: 'Profil güncellenemedi.'),
      );
    }
  }

  UserProfile _accept(Object? json) {
    final user = AuthUser.fromJson(json as Map<String, dynamic>);
    session.updateUser(user);
    _current = profileFor(user, academicCatalog());
    notifyListeners();
    return _current;
  }
}
