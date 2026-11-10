import 'package:flutter/material.dart';
import '../../../core/constants/app_university.dart';
import '../../../core/data/academic_catalog.dart';
import '../../auth/validation/registration_validators.dart';
import '../domain/profile_repository.dart';
import '../models/profile_destination.dart';
import '../models/user_profile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.userId,
    required this.repository,
  });

  final String? userId;
  final ProfileRepository? repository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  UserProfile? _profile;
  List<AcademicDepartment> _departments = const [];
  String? _departmentId;
  String? _loadError;
  String? _saveError;
  bool _loadingProfile = true;
  bool _loadingDepartments = false;
  bool _departmentError = false;
  bool _saving = false;
  bool _confirmingExit = false;

  bool get _hasIdentity => widget.userId?.trim().isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    if (widget.repository != null && _hasIdentity) _loadDepartments();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _loadError = null;
    });
    try {
      final source = widget.repository;
      if (!_hasIdentity) {
        throw const ProfileFailure('Kullanıcı kimliği doğrulanamadı.');
      }
      if (source == null) throw StateError('No profile repository');
      final profile = await source.fetchProfile();
      if (!mounted) return;
      if (profile.id != widget.userId || source.userId != widget.userId) {
        throw const ProfileFailure('Kullanıcı kimliği doğrulanamadı.');
      }
      _profile = profile;
      _firstName.text = profile.firstName;
      _lastName.text = profile.lastName ?? '';
      _phone.text = profile.phone ?? '';
      _departmentId = profile.departmentId;
    } on ProfileFailure catch (error) {
      if (mounted) _loadError = error.message;
    } catch (_) {
      if (mounted) {
        _loadError = 'Profil bilgileri alınamadı. Tekrar deneyebilirsin.';
      }
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _loadingDepartments = true;
      _departmentError = false;
    });
    try {
      final entries = await widget.repository!.fetchDepartments();
      if (!mounted) return;
      final ids = <String>{};
      _departments =
          entries.where((entry) {
            final id = entry.id;
            return id != null && id.trim().isNotEmpty && ids.add(id);
          }).toList();
    } catch (_) {
      if (mounted) _departmentError = true;
    } finally {
      if (mounted) setState(() => _loadingDepartments = false);
    }
  }

  ProfileChanges get _changes {
    final profile = _profile;
    if (profile == null) return const ProfileChanges();
    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    final phone = _phone.text.trim();
    return ProfileChanges(
      firstName: firstName == profile.firstName.trim() ? null : firstName,
      lastName: lastName == (profile.lastName ?? '').trim() ? null : lastName,
      phone: phone == (profile.phone ?? '').trim() ? null : phone,
      departmentId:
          _departmentId == profile.departmentId ? null : _departmentId,
    );
  }

  Future<void> _save() async {
    if (_saving || _profile == null) return;
    final changes = _changes;
    if (changes.isEmpty) return;
    final invalid = _form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final field = invalid.first;
        if (mounted && field.mounted) {
          Scrollable.ensureVisible(
            field.context,
            alignment: .2,
            duration: const Duration(milliseconds: 180),
          );
        }
      });
      return;
    }
    final source = widget.repository!;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (source.userId != widget.userId) {
        throw const ProfileFailure('Kullanıcı kimliği doğrulanamadı.');
      }
      final saved = await source.updateProfile(changes);
      if (!mounted) return;
      if (saved.id != widget.userId || source.userId != widget.userId) {
        throw const ProfileFailure('Kullanıcı kimliği doğrulanamadı.');
      }
      Navigator.of(context).pop(true);
    } on ProfileFailure catch (error) {
      if (mounted) _saveError = error.message;
    } catch (_) {
      if (mounted) {
        _saveError = 'Profil bilgileri güncellenemedi. Tekrar deneyebilirsin.';
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discardChanges() async {
    if (_saving || _confirmingExit) return;
    _confirmingExit = true;
    final discard = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            scrollable: true,
            title: const Text('Kaydedilmemiş Değişiklikler'),
            content: const Text(
              'Kaydetmeden çıkarsan değişikliklerin kaybolacak.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Düzenlemeye Devam Et'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Kaydetmeden Çık'),
              ),
            ],
          ),
    );
    _confirmingExit = false;
    if (mounted && discard == true) Navigator.of(context).pop();
  }

  Widget _card(String title, IconData icon, List<Widget> fields) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.onPrimary,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          for (final field in fields) ...[const SizedBox(height: 14), field],
        ],
      ),
    );
  }

  Widget _readOnly(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(value),
    ],
  );

  Widget _departmentField(UserProfile profile) {
    final hasSelected = _departments.any((item) => item.id == _departmentId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hasSelected) ...[
          _readOnly(
            'Bölüm',
            profile.department.trim().isEmpty
                ? 'Bölüm bilgisi bulunmuyor.'
                : profile.department,
          ),
          const SizedBox(height: 8),
        ],
        if (_loadingDepartments)
          const LinearProgressIndicator(semanticsLabel: 'Bölümler yükleniyor')
        else if (_departmentError) ...[
          const Text('Bölüm listesi alınamadı.'),
          TextButton(
            onPressed: _saving ? null : _loadDepartments,
            child: const Text('Bölümleri Yeniden Yükle'),
          ),
        ] else if (_departments.isEmpty)
          const Text('Seçilebilecek bölüm bulunmuyor.')
        else
          DropdownButtonFormField<String>(
            key: const ValueKey('edit-profile-department'),
            value: hasSelected ? _departmentId : null,
            isExpanded: true,
            itemHeight: null,
            decoration: const InputDecoration(
              labelText: 'Bölüm',
              errorMaxLines: 3,
            ),
            items: [
              for (final entry in _departments)
                DropdownMenuItem(value: entry.id, child: Text(entry.name)),
            ],
            selectedItemBuilder:
                (context) => [
                  for (final entry in _departments)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        entry.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
            onChanged:
                _saving ? null : (id) => setState(() => _departmentId = id),
            validator:
                (id) =>
                    _changes.departmentId != null &&
                            !_departments.any((item) => item.id == id)
                        ? 'Geçerli bir bölüm seçin.'
                        : null,
          ),
      ],
    );
  }

  Widget _fields(UserProfile profile) {
    final colors = Theme.of(context).colorScheme;
    final email = profile.email?.trim();
    return Form(
      key: _form,
      onChanged: () => setState(() => _saveError = null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _card('Kişisel Bilgiler', Icons.person_outline, [
            TextFormField(
              key: const ValueKey('edit-profile-first-name'),
              controller: _firstName,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: RegistrationValidators.requiredText,
              decoration: const InputDecoration(labelText: 'Ad'),
            ),
            TextFormField(
              key: const ValueKey('edit-profile-last-name'),
              controller: _lastName,
              enabled: !_saving,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: RegistrationValidators.requiredText,
              decoration: const InputDecoration(labelText: 'Soyad'),
            ),
            TextFormField(
              key: const ValueKey('edit-profile-phone'),
              controller: _phone,
              enabled: !_saving,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator:
                  (value) =>
                      _changes.phone?.isNotEmpty == true
                          ? RegistrationValidators.phone(value)
                          : null,
              decoration: const InputDecoration(
                labelText: 'Telefon Numarası',
                errorMaxLines: 3,
              ),
            ),
            _readOnly(
              'E-posta',
              email?.isNotEmpty == true
                  ? email!
                  : 'E-posta bilgisi bulunmuyor.',
            ),
            const Text('E-posta bu ekrandan değiştirilemez.'),
          ]),
          const SizedBox(height: 16),
          _card('Eğitim Bilgileri', Icons.school_outlined, [
            _readOnly('Üniversite', studyCoUniversityName),
            _departmentField(profile),
          ]),
          const SizedBox(height: 20),
          if (_saveError != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(_saveError!, style: TextStyle(color: colors.error)),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            key: const ValueKey('edit-profile-save'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.secondary,
              foregroundColor: colors.primary,
              elevation: 0,
            ),
            onPressed: _saving || _changes.isEmpty ? null : _save,
            child:
                _saving
                    ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Kaydediliyor',
                      ),
                    )
                    : const Text(
                      'Değişiklikleri Kaydet',
                      textAlign: TextAlign.center,
                    ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return PopScope(
      canPop: !_saving && _changes.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_changes.isEmpty) _discardChanges();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(ProfileDestination.edit.label)),
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Kişisel ve eğitim bilgilerini düzenle.'),
                    const SizedBox(height: 16),
                    if (_loadingProfile)
                      const Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Profil yükleniyor',
                        ),
                      )
                    else if (profile != null)
                      _fields(profile)
                    else ...[
                      Text(_loadError!),
                      if (_hasIdentity && widget.repository != null)
                        TextButton(
                          onPressed: _loadProfile,
                          child: const Text('Tekrar Dene'),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
