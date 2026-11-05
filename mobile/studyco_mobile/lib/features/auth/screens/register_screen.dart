import 'package:flutter/material.dart';
import '../../../core/data/academic_catalog.dart';
import '../../../core/widgets/academic_catalog_scope.dart';

import '../validation/registration_validators.dart';
import '../widgets/auth_form_widgets.dart';

typedef _RegistrationData =
    ({
      String firstName,
      String lastName,
      String email,
      String phone,
      DateTime birthDate,
      String department,
      bool acceptedTerms,
      String password,
    });

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _dateKey = GlobalKey<FormFieldState<DateTime>>();
  final _departmentKey = GlobalKey<FormFieldState<String>>();
  final _consentKey = GlobalKey<FormFieldState<bool>>();
  AcademicCatalog? _academicCatalog;
  bool _submitted = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AcademicCatalogScope.of(context);
    if (_academicCatalog != null && _academicCatalog != next) {
      _departmentKey.currentState?.didChange(null);
    }
    _academicCatalog = next;
  }

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _email,
      _phone,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!mounted || _busy) return;
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    // Local form snapshot, not a JSON payload or an API contract.
    final registration = (
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      birthDate: _dateKey.currentState!.value!,
      department: _departmentKey.currentState!.value!,
      acceptedTerms: _consentKey.currentState!.value!,
      password: _password.text,
    );
    setState(() => _busy = true);
    try {
      FocusScope.of(context).unfocus();
      await _submitRegistration(registration);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // No transport is connected yet. Do not persist or log the form snapshot.
  Future<void> _submitRegistration(_RegistrationData _) =>
      Future<void>.sync(() {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Kayıt hizmeti henüz kullanıma açılmadı. Hesap oluşturulmadı.',
            ),
          ),
        );
      });

  Future<void> _pickBirthDate(FormFieldState<DateTime> field) async {
    FocusScope.of(context).unfocus();
    final now = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: field.value ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Doğum Tarihi',
      cancelText: 'İptal',
      confirmText: 'Seç',
      fieldLabelText: 'Doğum Tarihi',
      fieldHintText: 'GG/AA/YYYY',
      errorFormatText: 'Geçerli bir tarih girin.',
      errorInvalidText: 'Geçerli aralıkta bir tarih seçin.',
    );
    if (!mounted || selected == null) return;
    field.didChange(selected);
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    IconData? icon,
    required FormFieldValidator<String> validator,
    String? hint,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return AuthLabeledField(
      label: label,
      field: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        textCapitalization: capitalization,
        autofillHints: autofillHints,
        autocorrect: false,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
          prefixIcon: icon == null ? null : Icon(icon),
        ),
      ),
    );
  }

  Widget _birthDateField() {
    return AuthLabeledField(
      label: 'DOĞUM TARİHİ',
      field: FormField<DateTime>(
        key: _dateKey,
        validator: (value) => RegistrationValidators.birthDate(value),
        builder: (field) {
          final date = field.value;
          final text =
              date == null
                  ? 'GG/AA/YYYY'
                  : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _pickBirthDate(field),
            child: InputDecorator(
              isEmpty: date == null,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.calendar_month_outlined),
                errorText: field.errorText,
              ),
              child: Text(
                text,
                style: TextStyle(
                  color:
                      date == null
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final academic = AcademicCatalogScope.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 20 : 28,
                  vertical: 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/images/studyco_logo.png',
                            width: 240,
                            semanticLabel: 'StudyCo logosu',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Hesap Oluştur',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 28),
                        AuthFormCard(
                          compact: compact,
                          child: AutofillGroup(
                            child: Form(
                              key: _formKey,
                              autovalidateMode:
                                  _submitted
                                      ? AutovalidateMode.onUserInteraction
                                      : AutovalidateMode.disabled,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _textField(
                                          label: 'AD',
                                          hint: 'Adınız',
                                          controller: _firstName,
                                          validator:
                                              RegistrationValidators
                                                  .requiredText,
                                          capitalization:
                                              TextCapitalization.words,
                                          autofillHints: const [
                                            AutofillHints.givenName,
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _textField(
                                          label: 'SOYAD',
                                          hint: 'Soyadınız',
                                          controller: _lastName,
                                          validator:
                                              RegistrationValidators
                                                  .requiredText,
                                          capitalization:
                                              TextCapitalization.words,
                                          autofillHints: const [
                                            AutofillHints.familyName,
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _birthDateField(),
                                  const SizedBox(height: 20),
                                  _textField(
                                    label: 'E-POSTA ADRESİ',
                                    controller: _email,
                                    icon: Icons.email_outlined,
                                    validator: RegistrationValidators.email,
                                    hint: 'ornek@gmail.com',
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                  ),
                                  const SizedBox(height: 20),
                                  _textField(
                                    label: 'TELEFON NUMARASI',
                                    controller: _phone,
                                    icon: Icons.phone_outlined,
                                    validator: RegistrationValidators.phone,
                                    hint: '05xx xxx xx xx',
                                    keyboardType: TextInputType.phone,
                                    autofillHints: const [
                                      AutofillHints.telephoneNumber,
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  AuthLabeledField(
                                    label: 'OKUDUĞUN BÖLÜM',
                                    field: DropdownButtonFormField<String>(
                                      key: _departmentKey,
                                      isExpanded: true,
                                      hint: const Text('Bölüm seçin'),
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(Icons.school_outlined),
                                      ),
                                      items:
                                          academic.departmentNames
                                              .map(
                                                (department) =>
                                                    DropdownMenuItem(
                                                      value: department,
                                                      child: Text(
                                                        department,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                              )
                                              .toList(),
                                      onChanged:
                                          academic.departments.isEmpty
                                              ? null
                                              : (_) {},
                                      validator:
                                          (value) =>
                                              academic.findDepartment(value) ==
                                                      null
                                                  ? RegistrationValidators.requiredText(
                                                    null,
                                                  )
                                                  : null,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  AuthPasswordField(
                                    controller: _password,
                                    label: 'ŞİFRE',
                                    validator: RegistrationValidators.password,
                                    onChanged: (_) {
                                      if (_submitted) {
                                        _formKey.currentState!.validate();
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  AuthPasswordField(
                                    controller: _confirmation,
                                    label: 'ŞİFRE TEKRAR',
                                    validator:
                                        (value) =>
                                            RegistrationValidators.confirmPassword(
                                              value,
                                              _password.text,
                                            ),
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _submit(),
                                  ),
                                  const SizedBox(height: 16),
                                  FormField<bool>(
                                    key: _consentKey,
                                    initialValue: false,
                                    validator: RegistrationValidators.consent,
                                    builder:
                                        (field) => Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            CheckboxListTile(
                                              contentPadding: EdgeInsets.zero,
                                              controlAffinity:
                                                  ListTileControlAffinity
                                                      .leading,
                                              activeColor: colors.secondary,
                                              value: field.value ?? false,
                                              onChanged:
                                                  (value) => field.didChange(
                                                    value ?? false,
                                                  ),
                                              title: const Text(
                                                'Kullanım Koşulları ve Gizlilik Politikası’nı kabul ediyorum.',
                                                style: TextStyle(fontSize: 14),
                                              ),
                                            ),
                                            if (field.hasError)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 12,
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  field.errorText!,
                                                  style: TextStyle(
                                                    color: colors.error,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                  ),
                                  const SizedBox(height: 20),
                                  FilledButton(
                                    onPressed: _busy ? null : _submit,
                                    child: const Text('Kayıt Ol'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Zaten hesabın var mı?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 16,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: colors.secondary,
                              ),
                              child: const Text('Giriş Yap'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
