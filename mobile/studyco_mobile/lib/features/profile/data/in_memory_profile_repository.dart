import '../../../core/data/academic_catalog.dart';
import '../../auth/validation/registration_validators.dart';
import '../domain/profile_repository.dart';
import '../models/user_profile.dart';

/// Preview data for one explicit identity. No persistence or HTTP.
class InMemoryProfileRepository extends ProfileRepository {
  InMemoryProfileRepository({
    required UserProfile initialProfile,
    required AcademicCatalog academicCatalog,
  }) : _current = initialProfile,
       _departments = List.unmodifiable(
         academicCatalog.departments.where(
           (item) => item.id?.trim().isNotEmpty == true,
         ),
       );

  UserProfile _current;
  final List<AcademicDepartment> _departments;
  @override
  String? get userId => _current.id;
  @override
  UserProfile get current => _current;

  void _requireIdentity() {
    if (userId?.trim().isNotEmpty != true) {
      throw const ProfileFailure('Kullanıcı kimliği doğrulanamadı.');
    }
  }

  @override
  Future<UserProfile> fetchProfile() async {
    _requireIdentity();
    return _current;
  }

  @override
  Future<List<AcademicDepartment>> fetchDepartments() async => _departments;

  @override
  Future<UserProfile> updateProfile(ProfileChanges changes) async {
    _requireIdentity();
    if (changes.isEmpty) return _current;
    final firstName = changes.firstName?.trim() ?? _current.firstName;
    final lastName = changes.lastName?.trim() ?? _current.lastName;
    if (firstName.trim().isEmpty || lastName?.trim().isNotEmpty != true) {
      throw const ProfileFailure('Ad ve soyad boş bırakılamaz.');
    }

    final phone = changes.phone?.trim();
    if (phone != null && phone.isNotEmpty) {
      final error = RegistrationValidators.phone(phone);
      if (error != null) throw ProfileFailure(error);
    }
    AcademicDepartment? selectedDepartment;
    final departmentId = changes.departmentId;
    if (departmentId != null && departmentId != _current.departmentId) {
      for (final department in _departments) {
        if (department.id == departmentId) {
          selectedDepartment = department;
          break;
        }
      }
      if (selectedDepartment == null) {
        throw const ProfileFailure('Geçerli bir bölüm seçin.');
      }
    }

    final nextPhone =
        phone == null ? _current.phone : (phone.isEmpty ? null : phone);
    if (firstName == _current.firstName &&
        lastName == _current.lastName &&
        nextPhone == _current.phone &&
        selectedDepartment == null) {
      return _current;
    }

    _current = UserProfile(
      id: _current.id,
      firstName: firstName,
      lastName: lastName,
      phone: nextPhone,
      email: _current.email,
      departmentId: selectedDepartment?.id ?? _current.departmentId,
      department: selectedDepartment?.name ?? _current.department,
      university: _current.university,
      campus: _current.campus,
      unreadMessages: _current.unreadMessages,
    );
    notifyListeners();
    return _current;
  }
}
