import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/app.dart';
import 'package:studyco_mobile/app/debug/home_preview.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/auth/data/password_reset_repository.dart';
import 'package:studyco_mobile/features/auth/debug/password_reset_preview.dart';
import 'package:studyco_mobile/features/auth/screens/login_screen.dart';
import 'package:studyco_mobile/features/auth/screens/password_reset_screens.dart';
import 'package:studyco_mobile/features/auth/widgets/session_logout_scope.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';
import 'package:studyco_mobile/features/profile/data/in_memory_profile_repository.dart';
import 'package:studyco_mobile/features/profile/domain/profile_repository.dart';
import 'package:studyco_mobile/features/profile/models/user_profile.dart';
import 'package:studyco_mobile/features/profile/screens/profile_screen.dart';
import 'package:studyco_mobile/features/profile/widgets/profile_repository_scope.dart';
import 'package:studyco_mobile/features/settings/screens/settings_screen.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> openSettings(WidgetTester tester) async {
  await tap(tester, find.byKey(const ValueKey('profile-settings')));
  await tester.pumpAndSettle();
}

Widget profileApp({
  UserProfile user = sampleHomeUser,
  ProfileRepository? repository,
  Future<void> Function()? logout,
}) => MaterialApp(
  theme: AppTheme.light,
  builder:
      (context, child) => ProfileRepositoryScope(
        repository: repository,
        child: SessionLogoutScope(
          userId: logout == null ? null : user.id,
          endSession: logout ?? () async {},
          child: child!,
        ),
      ),
  home: ProfileScreen(user: user, onDestination: (_) {}),
);

void main() {
  testWidgets(
    'settings uses the existing reset route, verified profile email and About',
    (tester) async {
      final profile = InMemoryProfileRepository(
        initialProfile: sampleHomeUser,
        academicCatalog: previewProfileCatalog(),
      );
      addTearDown(profile.dispose);
      const stale = UserProfile(
        id: 'mock-preview-student',
        firstName: 'Rümeysa',
        department: '',
        campus: '',
        email: 'old@example.test',
      );
      await tester.pumpWidget(profileApp(user: stale, repository: profile));
      await tester.pumpAndSettle();
      await openSettings(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        find.text('Hesabını ve uygulama bilgilerini yönet.'),
        findsOneWidget,
      );
      await tap(tester, find.text('E-posta Adresim'));
      await tester.pumpAndSettle();
      expect(find.text(sampleHomeUser.email!), findsOneWidget);
      expect(find.text(stale.email!), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await tap(tester, find.text('Kapat'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('StudyCo Hakkında'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('StudyCo ile öğrenmek ve öğretmek daha kolay!'),
        findsOneWidget,
      );
      await tap(tester, find.text('Kapat'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Şifremi Değiştir'));
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        sampleHomeUser.email,
      );
      await tap(tester, find.text('Doğrulama Kodu Gönder'));
      await tester.pumpAndSettle();
      expect(find.text(ResetUnavailable.message), findsOneWidget);
      expect(find.byType(EmailVerificationScreen), findsNothing);
      await tap(tester, find.text('Ayarlara Dön'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    },
  );

  testWidgets(
    'small settings and delete dialog fit and mismatched profiles remain private',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 560);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final other = InMemoryProfileRepository(
        initialProfile: sampleHomeUser,
        academicCatalog: previewProfileCatalog(),
      );
      addTearDown(other.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: ProfileRepositoryScope(repository: other, child: child!),
              ),
          home: const SettingsScreen(
            user: UserProfile(
              id: 'another-user',
              firstName: 'Ece',
              department: '',
              campus: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('E-posta Adresim'));
      await tester.pumpAndSettle();
      expect(find.text('Kayıtlı e-posta bilgisi bulunmuyor.'), findsOneWidget);
      expect(find.text(sampleHomeUser.email!), findsNothing);
      await tap(tester, find.text('Kapat'));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Hesabımı Sil'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bu işlem geri alınamaz.'), findsOneWidget);
      expect(
        find.text('Hesap silme işlemi henüz kullanılamıyor.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Hesabımı Sil'),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Hesabın silindi.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('logout cancels cleanly and failures retain the current screen', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      profileApp(
        logout: () {
          calls++;
          return pending.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('profile-logout')));
    await tester.pumpAndSettle();
    expect(
      find.text('Hesabından çıkış yapmak istediğine emin misin?'),
      findsOneWidget,
    );
    await tap(tester, find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(ProfileScreen), findsOneWidget);
    await openSettings(tester);
    await tap(tester, find.widgetWithText(ListTile, 'Çıkış Yap'));
    await tester.pumpAndSettle();
    final button = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    );
    await tap(tester, button);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(calls, 1);
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(
      find.text('Çıkış yapılamadı. Tekrar deneyebilirsin.'),
      findsOneWidget,
    );
    await tap(tester, find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  for (final fromSettings in [true, false]) {
    testWidgets(
      'HOME_PREVIEW logout clears protected routes and data from ${fromSettings ? 'settings' : 'profile'}',
      (tester) async {
        if (!HomePreview.enabled || PasswordResetPreview.screen() != null) {
          return;
        }
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();
        final home = find.byType(HomeScreen);
        final source =
            ProfileRepositoryScope.forUser(
              tester.element(home),
              sampleHomeUser,
            )!;
        await source.updateProfile(
          const ProfileChanges(firstName: 'Oturum Örneği'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Oturum Örneği'), findsOneWidget);
        await tap(tester, find.byKey(const ValueKey('home-nav-3')));
        await tester.pumpAndSettle();
        if (fromSettings) {
          await openSettings(tester);
          await tap(tester, find.widgetWithText(ListTile, 'Çıkış Yap'));
        } else {
          await tap(tester, find.byKey(const ValueKey('profile-logout')));
        }
        await tester.pumpAndSettle();
        await tap(tester, find.widgetWithText(FilledButton, 'Çıkış Yap'));
        await tester.pumpAndSettle();
        final login = find.byType(LoginScreen);
        expect(login, findsOneWidget);
        expect(Navigator.of(tester.element(login)).canPop(), isFalse);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(home, findsNothing);
        expect(find.byType(ProfileScreen), findsNothing);
        expect(find.byType(SettingsScreen), findsNothing);
        expect(
          ProfileRepositoryScope.forUser(tester.element(login), sampleHomeUser),
          isNull,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(const MyApp());
        await tester.pumpAndSettle();
        final nextSource = ProfileRepositoryScope.forUser(
          tester.element(home),
          sampleHomeUser,
        );
        expect(nextSource, isNot(same(source)));
        expect(nextSource?.current, same(sampleHomeUser));
        expect(find.text('Oturum Örneği'), findsNothing);
      },
    );
  }
}
