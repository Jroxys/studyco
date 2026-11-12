import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/app.dart';
import 'package:studyco_mobile/app/debug/home_preview.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/core/constants/app_university.dart';
import 'package:studyco_mobile/core/data/academic_catalog.dart';
import 'package:studyco_mobile/features/auth/debug/password_reset_preview.dart';
import 'package:studyco_mobile/features/profile/data/in_memory_profile_repository.dart';
import 'package:studyco_mobile/features/profile/domain/profile_repository.dart';
import 'package:studyco_mobile/features/profile/models/user_profile.dart';
import 'package:studyco_mobile/features/profile/screens/profile_screen.dart';
import 'package:studyco_mobile/features/profile/widgets/profile_repository_scope.dart';

const first = ValueKey('edit-profile-first-name');
const last = ValueKey('edit-profile-last-name');
const phone = ValueKey('edit-profile-phone');
const department = ValueKey('edit-profile-department');
const save = ValueKey('edit-profile-save');
const edit = ValueKey('profile-edit');

class ControlledProfile extends InMemoryProfileRepository {
  ControlledProfile()
    : super(
        initialProfile: sampleHomeUser,
        academicCatalog: previewProfileCatalog(),
      );

  ProfileChanges? submitted;
  Completer<void>? gate;
  int calls = 0;
  bool failLoad = false;
  bool failDepartments = false;
  Completer<void>? loadGate;

  @override
  Future<UserProfile> fetchProfile() async {
    await loadGate?.future;
    if (failLoad) throw StateError('offline');
    return super.fetchProfile();
  }

  @override
  Future<List<AcademicDepartment>> fetchDepartments() async {
    if (failDepartments) throw StateError('offline');
    return super.fetchDepartments();
  }

  @override
  Future<UserProfile> updateProfile(ProfileChanges changes) async {
    calls++;
    submitted = changes;
    await gate?.future;
    return super.updateProfile(changes);
  }
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pump();
}

Future<void> mount(
  WidgetTester tester, {
  ProfileRepository? repository,
  UserProfile user = sampleHomeUser,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: ProfileRepositoryScope(
              repository: repository,
              child: child!,
            ),
          ),
      home: ProfileScreen(user: user, onDestination: (_) {}),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'prefills fields and saves only changed values using department ID',
    (tester) async {
      final source = ControlledProfile();
      addTearDown(source.dispose);
      await mount(tester, repository: source);
      await tap(tester, find.byKey(edit));
      await tester.pumpAndSettle();
      expect(find.text('Profili Düzenle'), findsOneWidget);
      String field(Key key) =>
          tester.widget<TextFormField>(find.byKey(key)).controller!.text;
      expect(field(first), sampleHomeUser.firstName);
      expect(field(last), sampleHomeUser.lastName);
      expect(field(phone), sampleHomeUser.phone);
      expect(find.text(sampleHomeUser.email!), findsOneWidget);
      expect(find.text(studyCoUniversityName), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(tester.widget<FilledButton>(find.byKey(save)).onPressed, isNull);
      await tester.enterText(find.byKey(first), '  Ayşe  ');
      await tester.enterText(find.byKey(last), ' Yılmaz ');
      await tester.enterText(find.byKey(phone), ' +90 532 123 45 67 ');
      await tap(tester, find.byKey(department));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Yazılım Mühendisliği').last);
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(save));
      await tester.pumpAndSettle();
      expect(source.calls, 1);
      expect(source.submitted?.firstName, 'Ayşe');
      expect(source.submitted?.lastName, 'Yılmaz');
      expect(source.submitted?.phone, '+90 532 123 45 67');
      expect(
        source.submitted?.departmentId,
        'mock-department-software-engineering',
      );
      expect(source.current.email, sampleHomeUser.email);
      expect(source.current.id, sampleHomeUser.id);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Yazılım Mühendisliği'), findsOneWidget);
      expect(find.text('Profil bilgilerin güncellendi.'), findsOneWidget);
    },
  );

  testWidgets(
    'failure keeps draft and stored profile, blocks duplicates and confirms discard',
    (tester) async {
      final source = ControlledProfile()..gate = Completer<void>();
      addTearDown(source.dispose);
      await mount(tester, repository: source);
      await tap(tester, find.byKey(edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(first), 'Ece');
      await tap(tester, find.byKey(save));
      expect(tester.widget<FilledButton>(find.byKey(save)).onPressed, isNull);
      expect(source.calls, 1);
      source.gate!.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        find.text('Profil bilgileri güncellenemedi. Tekrar deneyebilirsin.'),
        findsOneWidget,
      );
      expect(source.current, same(sampleHomeUser));
      expect(find.text('Ece'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Kaydedilmemiş Değişiklikler'), findsOneWidget);
      await tap(tester, find.text('Düzenlemeye Devam Et'));
      await tester.pumpAndSettle();
      expect(find.text('Ece'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Kaydetmeden Çık'));
      await tester.pumpAndSettle();
      expect(find.text(sampleHomeUser.fullName), findsOneWidget);
    },
  );

  testWidgets(
    'loading and catalogue errors are recoverable, missing ID is explicit',
    (tester) async {
      final source =
          ControlledProfile()
            ..loadGate = Completer<void>()
            ..failLoad = true
            ..failDepartments = true;
      addTearDown(source.dispose);
      await mount(tester, repository: source);
      await tap(tester, find.byKey(edit));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      source.loadGate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Profil bilgileri alınamadı. Tekrar deneyebilirsin.'),
        findsOneWidget,
      );
      source.failLoad = false;
      await tap(tester, find.text('Tekrar Dene'));
      await tester.pumpAndSettle();
      expect(find.text('Bölüm listesi alınamadı.'), findsOneWidget);
      source.failDepartments = false;
      await tap(tester, find.text('Bölümleri Yeniden Yükle'));
      await tester.pumpAndSettle();
      expect(find.byKey(department), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await mount(
        tester,
        user: const UserProfile(firstName: 'Ece', department: '', campus: ''),
      );
      await tap(tester, find.byKey(edit));
      await tester.pumpAndSettle();
      expect(find.text('Kullanıcı kimliği doğrulanamadı.'), findsOneWidget);
      expect(find.byKey(save), findsNothing);
    },
  );

  testWidgets(
    'small screen with keyboard can validate and clear an optional phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final source = ControlledProfile();
      addTearDown(source.dispose);
      await mount(tester, repository: source, scale: 1.5);
      await tap(tester, find.byKey(edit));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(phone));
      await tester.enterText(find.byKey(phone), 'abc');
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(save));
      await tester.pumpAndSettle();
      expect(find.text('Geçerli bir telefon numarası girin.'), findsOneWidget);
      expect(source.calls, 0);
      await tester.ensureVisible(find.byKey(phone));
      await tester.enterText(find.byKey(phone), '');
      await tap(tester, find.byKey(save));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(source.submitted?.phone, '');
      expect(source.submitted?.firstName, isNull);
      expect(source.current.phone, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'repository rejects unverified IDs and preserves the previous record',
    () async {
      final source = ControlledProfile();
      addTearDown(source.dispose);
      await expectLater(
        source.updateProfile(const ProfileChanges(departmentId: 'Tıp')),
        throwsA(isA<ProfileFailure>()),
      );
      expect(source.current, same(sampleHomeUser));
    },
  );

  testWidgets(
    'HOME_PREVIEW profile changes reach Home and reopening the editor',
    (tester) async {
      if (!HomePreview.enabled || PasswordResetPreview.screen() != null) return;
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('home-nav-3')));
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(edit));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(first), 'Ece');
      await tap(tester, find.byKey(save));
      await tester.pumpAndSettle();
      expect(find.text('Ece Örnek'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Ece'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('home-nav-3')));
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(edit));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(find.byKey(first)).controller!.text,
        'Ece',
      );
    },
  );
}
