import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/app.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/auth/screens/register_screen.dart';
import 'package:studyco_mobile/features/auth/validation/registration_validators.dart';

void main() {
  Future<({DateTime birthDate, String department})> fillValidRegistration(
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const RegisterScreen()),
    );
    final fields = find.byType(TextFormField);
    final values = [
      '  Sample  ',
      '  Student  ',
      ' student@example.com ',
      ' 0555 123 45 67 ',
      ' secret123 ',
      ' secret123 ',
    ];
    for (var index = 0; index < values.length; index++) {
      await tester.ensureVisible(fields.at(index));
      await tester.enterText(fields.at(index), values[index]);
    }
    final dateField = find.byType(FormField<DateTime>);
    await tester.ensureVisible(dateField);
    await tester.tap(dateField);
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    final birthDate = picker.initialDate!;
    await tester.tap(find.text(picker.confirmText!));
    await tester.pumpAndSettle();

    final departmentField = find.byType(DropdownButtonFormField<String>);
    final department =
        tester
            .widget<DropdownButton<String>>(
              find.descendant(
                of: departmentField,
                matching: find.byType(DropdownButton<String>),
              ),
            )
            .items!
            .first
            .value!;
    await tester.ensureVisible(departmentField);
    await tester.tap(departmentField);
    await tester.pumpAndSettle();
    await tester.tap(find.text(department).last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    return (birthDate: birthDate, department: department);
  }

  testWidgets(
    'Registration preserves selections, coalesces button and Done, and permits retry',
    (tester) async {
      final selected = await fillValidRegistration(tester);
      await tester.ensureVisible(find.byType(FilledButton));
      final submit =
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!;
      final done =
          tester.widget<TextField>(find.byType(TextField).last).onSubmitted!;

      submit();
      done(' secret123 ');
      submit();
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text(
          'Kayıt hizmeti henüz kullanıma açılmadı. Hesap oluşturulmadı.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .state<FormFieldState<DateTime>>(find.byType(FormField<DateTime>))
            .value,
        selected.birthDate,
      );
      expect(
        tester
            .state<FormFieldState<String>>(
              find.byType(DropdownButtonFormField<String>),
            )
            .value,
        selected.department,
      );
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      final textFields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(textFields[0].controller!.text, '  Sample  ');
      expect(textFields[1].controller!.text, '  Student  ');
      expect(textFields[2].controller!.text, ' student@example.com ');
      expect(textFields[3].controller!.text, ' 0555 123 45 67 ');
      expect(textFields[4].controller!.text, ' secret123 ');
      expect(textFields[5].controller!.text, ' secret123 ');

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      submit();
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Registration submission is safe after the screen is removed', (
    tester,
  ) async {
    await fillValidRegistration(tester);
    final submit =
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!;
    submit();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    submit();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('Registration validation rejects invalid and missing values', () {
    expect(RegistrationValidators.requiredText('  '), isNotNull);
    expect(RegistrationValidators.requiredText('Ayşe'), isNull);
    expect(RegistrationValidators.email('invalid'), isNotNull);
    expect(RegistrationValidators.email(' student@example.com '), isNull);
    for (final phone in [
      '0555 123 45 67',
      '5551234567',
      '+90 (555) 123-45-67',
      '+4915123456789',
    ]) {
      expect(RegistrationValidators.phone(phone), isNull);
    }
    for (final phone in [
      '',
      '1234',
      'abcdefghij',
      '0555123456',
      '055512345678',
      '+0123456789',
    ]) {
      expect(RegistrationValidators.phone(phone), isNotNull);
    }
    final today = DateTime(2026, 10, 25);
    expect(RegistrationValidators.birthDate(null, today: today), isNotNull);
    expect(
      RegistrationValidators.birthDate(DateTime(2026, 10, 26), today: today),
      isNotNull,
    );
    expect(RegistrationValidators.birthDate(today, today: today), isNull);
    expect(RegistrationValidators.password('1234567'), isNotNull);
    expect(RegistrationValidators.password('        '), isNotNull);
    expect(RegistrationValidators.password('12345678'), isNull);
    expect(RegistrationValidators.confirmPassword('', '12345678'), isNotNull);
    expect(
      RegistrationValidators.confirmPassword('different', '12345678'),
      isNotNull,
    );
    expect(
      RegistrationValidators.confirmPassword('12345678', '12345678'),
      isNull,
    );
    expect(RegistrationValidators.consent(false), isNotNull);
    expect(RegistrationValidators.consent(true), isNull);
  });

  testWidgets(
    'Registration opens from login and returns without replacing it',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.ensureVisible(find.text('Kayıt Ol'));
      await tester.tap(find.text('Kayıt Ol'));
      await tester.pumpAndSettle();
      expect(find.text('Hesap Oluştur'), findsOneWidget);
      expect(find.byType(RegisterScreen), findsOneWidget);
      await tester.ensureVisible(find.text('Giriş Yap'));
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();
      expect(find.text('Hoş geldin!'), findsOneWidget);
      expect(find.byType(RegisterScreen), findsNothing);
    },
  );

  testWidgets('Empty registration and keyboard fit a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const RegisterScreen()),
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump();
    await tester.ensureVisible(find.text('Kayıt Ol'));
    await tester.tap(find.text('Kayıt Ol'));
    await tester.pump();
    expect(find.text('Bu alan zorunludur.'), findsNWidgets(3));
    expect(find.text('Doğum tarihinizi seçin.'), findsOneWidget);
    expect(find.text('Devam etmek için koşulları onaylayın.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Registration checks consent and never reports account creation',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.ensureVisible(find.text('Kayıt Ol'));
      await tester.tap(find.text('Kayıt Ol'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      final values = [
        'Ayşe',
        'Yılmaz',
        'student@example.com',
        '05551234567',
        'secret123',
        'secret123',
      ];
      for (var i = 0; i < values.length; i++) {
        await tester.ensureVisible(fields.at(i));
        await tester.enterText(fields.at(i), values[i]);
      }
      await tester.ensureVisible(find.text('GG/AA/YYYY'));
      await tester.tap(find.text('GG/AA/YYYY'));
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(
        picker.lastDate.isAfter(DateUtils.dateOnly(DateTime.now())),
        isFalse,
      );
      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bilgisayar Mühendisliği').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('ŞİFRE: Şifreyi göster'));
      await tester.tap(find.byTooltip('ŞİFRE: Şifreyi göster'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(4)).obscureText,
        isFalse,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(5)).obscureText,
        isTrue,
      );
      await tester.ensureVisible(
        find.byTooltip('ŞİFRE TEKRAR: Şifreyi göster'),
      );
      await tester.tap(find.byTooltip('ŞİFRE TEKRAR: Şifreyi göster'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(5)).obscureText,
        isFalse,
      );
      await tester.ensureVisible(find.text('Kayıt Ol'));
      await tester.tap(find.text('Kayıt Ol'));
      await tester.pump();
      expect(
        find.text('Devam etmek için koşulları onaylayın.'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.ensureVisible(find.text('Kayıt Ol'));
      await tester.tap(find.text('Kayıt Ol'));
      await tester.pump();
      expect(
        find.text(
          'Kayıt hizmeti henüz kullanıma açılmadı. Hesap oluşturulmadı.',
        ),
        findsOneWidget,
      );
      expect(find.text('Hesap Oluştur'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
