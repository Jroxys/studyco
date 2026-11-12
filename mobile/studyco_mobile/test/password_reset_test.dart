import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/app.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/auth/data/password_reset_repository.dart';
import 'package:studyco_mobile/features/auth/debug/password_reset_preview.dart';
import 'package:studyco_mobile/features/auth/screens/login_screen.dart';
import 'package:studyco_mobile/features/auth/screens/password_reset_screens.dart';
import 'package:studyco_mobile/features/auth/validation/password_reset_validators.dart';
import 'package:studyco_mobile/features/auth/widgets/otp_code_field.dart';

class SpyRepository implements PasswordResetRepository {
  int calls = 0;
  Future<ResetChallenge> Function(String email)? requestHandler;
  Future<ResetGrant> Function(ResetChallenge challenge, String code)?
  verifyHandler;
  Future<ResetChallenge> Function(ResetChallenge challenge)? resendHandler;
  Future<void> Function(ResetGrant grant, String password)? updateHandler;
  @override
  Future<ResetChallenge> requestCode(String email) async {
    calls++;
    final handler = requestHandler;
    if (handler != null) return handler(email);
    throw const ResetUnavailable();
  }

  @override
  Future<ResetChallenge> resendCode(ResetChallenge challenge) async {
    calls++;
    final handler = resendHandler;
    if (handler != null) return handler(challenge);
    throw const ResetUnavailable();
  }

  @override
  Future<ResetGrant> verifyCode(ResetChallenge challenge, String code) async {
    calls++;
    final handler = verifyHandler;
    if (handler != null) return handler(challenge, code);
    throw const ResetUnavailable();
  }

  @override
  Future<void> updatePassword(ResetGrant grant, String password) async {
    calls++;
    final handler = updateHandler;
    if (handler != null) return handler(grant, password);
    throw const ResetUnavailable();
  }
}

void main() {
  Future<void> openNewPassword(
    WidgetTester tester,
    SpyRepository repository, {
    ResetGrant grant = const ResetGrant(token: 'test-only-grant'),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: NewPasswordScreen(repository: repository, grant: grant),
      ),
    );
  }

  Future<void> fillNewPassword(
    WidgetTester tester, {
    String password = ' secret123 ',
    String? confirmation,
  }) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, password);
    await tester.enterText(fields.last, confirmation ?? password);
    await tester.ensureVisible(find.byType(FilledButton));
  }

  testWidgets(
    'New password rejects empty, short, and mismatched inputs without service calls',
    (tester) async {
      final repository = SpyRepository();
      await openNewPassword(tester, repository);
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.text('Şifrenizi girin.'), findsOneWidget);
      expect(find.text('Şifrenizi tekrar girin.'), findsOneWidget);
      await fillNewPassword(tester, password: '1234567');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.text('Şifre en az 8 karakter olmalıdır.'), findsOneWidget);
      await fillNewPassword(
        tester,
        password: '12345678',
        confirmation: 'different',
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
      expect(repository.calls, 0);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'New password locks both fields, guards Done, preserves the payload, and clears errors on edits',
    (tester) async {
      final requests = <Completer<void>>[];
      final passwords = <String>[];
      const grant = ResetGrant(token: 'test-only-grant');
      final repository =
          SpyRepository()
            ..updateHandler = (receivedGrant, password) {
              expect(identical(receivedGrant, grant), isTrue);
              passwords.add(password);
              final pending = Completer<void>();
              requests.add(pending);
              return pending.future;
            };
      await openNewPassword(tester, repository, grant: grant);
      await fillNewPassword(tester);
      final submit =
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!;
      final done =
          tester.widget<TextField>(find.byType(TextField).last).onSubmitted!;
      submit();
      done(' secret123 ');
      submit();
      await tester.pump();
      expect(repository.calls, 1);
      expect(passwords, [' secret123 ']);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.readOnly, isTrue);
      }
      final editors = find.byType(EditableText);
      tester
          .state<EditableTextState>(editors.first)
          .updateEditingValue(const TextEditingValue(text: 'changed-first'));
      tester
          .state<EditableTextState>(editors.last)
          .updateEditingValue(
            const TextEditingValue(text: 'changed-confirmation'),
          );
      await tester.pump();
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.controller!.text, ' secret123 ');
      }
      requests.single.completeError(const ResetUnavailable());
      await tester.pumpAndSettle();
      expect(find.text(ResetUnavailable.message), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.readOnly, isFalse);
      }
      await tester.enterText(find.byType(TextFormField).first, 'updated123');
      await tester.pump();
      expect(find.text(ResetUnavailable.message), findsNothing);
      expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, 'updated123');
      await tester.pump();
      expect(find.text('Şifreler eşleşmiyor.'), findsNothing);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(repository.calls, 2);
      expect(passwords, [' secret123 ', 'updated123']);
      requests.last.completeError(StateError('controlled test failure'));
      await tester.pumpAndSettle();
      expect(
        find.text('İşlem tamamlanamadı. Lütfen daha sonra tekrar deneyin.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).last, 'changed-again');
      await tester.pump();
      expect(
        find.text('İşlem tamamlanamadı. Lütfen daha sonra tekrar deneyin.'),
        findsNothing,
      );
      expect(find.byType(NewPasswordScreen), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry
      in {
        ResetGrantFailure.invalidGrant:
            'Doğrulama yetkisi geçersiz. Şifre sıfırlama işlemini yeniden başlatın.',
        ResetGrantFailure.expiredGrant:
            'Doğrulama yetkisinin süresi dolmuş. Şifre sıfırlama işlemini yeniden başlatın.',
      }.entries) {
    testWidgets('New password handles typed grant failure ${entry.key.name}', (
      tester,
    ) async {
      final repository =
          SpyRepository()
            ..updateHandler = (_, _) => Future<void>.error(entry.key);
      await openNewPassword(tester, repository);
      await fillNewPassword(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(NewPasswordScreen), findsOneWidget);
      expect(repository.calls, 1);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.enterText(find.byType(TextFormField).first, 'another123');
      await tester.pump();
      expect(find.text(entry.value), findsNothing);
    });
  }

  testWidgets(
    'New password returns to login only on service success and removes reset history',
    (tester) async {
      final pending = Completer<void>();
      final repository =
          SpyRepository()..updateHandler = (_, _) => pending.future;
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          navigatorKey: navigatorKey,
          home: const LoginScreen(),
        ),
      );
      unawaited(
        navigatorKey.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => ForgotPasswordScreen(repository: repository),
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        navigatorKey.currentState!.push<void>(
          MaterialPageRoute(
            builder:
                (_) => EmailVerificationScreen(
                  repository: repository,
                  challenge: const ResetChallenge(
                    id: 'test',
                    email: 'student@example.com',
                  ),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      unawaited(
        navigatorKey.currentState!.push<void>(
          MaterialPageRoute(
            builder:
                (_) => NewPasswordScreen(
                  repository: repository,
                  grant: const ResetGrant(token: 'test-only-grant'),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await fillNewPassword(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.byType(NewPasswordScreen), findsOneWidget);
      expect(repository.calls, 1);
      expect(navigatorKey.currentState!.canPop(), isTrue);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(
        find.byType(ForgotPasswordScreen, skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byType(EmailVerificationScreen, skipOffstage: false),
        findsNothing,
      );
      expect(find.byType(NewPasswordScreen, skipOffstage: false), findsNothing);
      expect(navigatorKey.currentState!.canPop(), isFalse);
      expect(await navigatorKey.currentState!.maybePop(), isFalse);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(repository.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final succeeds in [false, true]) {
    testWidgets(
      'New password ignores completion after disposal (success: $succeeds)',
      (tester) async {
        final pending = Completer<void>();
        final repository =
            SpyRepository()..updateHandler = (_, _) => pending.future;
        await openNewPassword(tester, repository);
        await fillNewPassword(tester);
        final submit =
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!;
        submit();
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        if (succeeds) {
          pending.complete();
        } else {
          pending.completeError(ResetGrantFailure.expiredGrant);
        }
        await tester.pumpAndSettle();
        submit();
        await tester.pump();
        expect(repository.calls, 1);
        expect(find.byType(LoginScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  Future<void> openVerification(
    WidgetTester tester,
    SpyRepository repository,
    ResetChallenge challenge, {
    DateTime Function()? now,
  }) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: EmailVerificationScreen(
          repository: repository,
          challenge: challenge,
          now: now,
        ),
      ),
    );
  }

  TextButton resendButton(WidgetTester tester) => tester.widget<TextButton>(
    find.widgetWithText(TextButton, 'Yeniden Gönder'),
  );

  testWidgets(
    'Verification has no invented countdown or cooldown without timing',
    (tester) async {
      final repository = SpyRepository();
      const challenge = ResetChallenge(
        id: 'test',
        email: 'student@example.com',
      );
      expect(challenge.expiresAt, isNull);
      expect(challenge.resendAvailableAt, isNull);
      await openVerification(tester, repository, challenge);
      expect(find.text('Süre bilgisi yok.'), findsOneWidget);
      expect(find.text('01:00'), findsNothing);
      await tester.pump(const Duration(minutes: 2));
      expect(find.text('Süre bilgisi yok.'), findsOneWidget);
      expect(resendButton(tester).onPressed, isNotNull);
      await tester.ensureVisible(find.text('Yeniden Gönder'));
      await tester.tap(find.text('Yeniden Gönder'));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(find.text(ResetUnavailable.message), findsOneWidget);
      expect(resendButton(tester).onPressed, isNotNull);
      await tester.tap(find.text('Yeniden Gönder'));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
    },
  );

  testWidgets(
    'Verification uses absolute deadlines and unlocks resend exactly on time',
    (tester) async {
      var now = DateTime.utc(2026, 10, 29, 12);
      final repository = SpyRepository();
      final challenge = ResetChallenge(
        id: 'test',
        email: 'student@example.com',
        expiresAt: now.add(const Duration(seconds: 62)),
        resendAvailableAt: now.add(const Duration(milliseconds: 1500)),
      );
      await openVerification(tester, repository, challenge, now: () => now);
      expect(find.text('01:02'), findsOneWidget);
      expect(find.text('Yeniden gönderim: 00:02'), findsOneWidget);
      expect(resendButton(tester).onPressed, isNull);
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:01'), findsOneWidget);
      expect(find.text('Yeniden gönderim: 00:01'), findsOneWidget);
      expect(resendButton(tester).onPressed, isNull);
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:00'), findsOneWidget);
      expect(resendButton(tester).onPressed, isNotNull);
      expect(repository.calls, 0);
    },
  );

  testWidgets(
    'Verification accepts server verification even after displayed time reaches zero',
    (tester) async {
      final now = DateTime.utc(2026, 10, 29, 12);
      final repository = SpyRepository();
      final challenge = ResetChallenge(
        id: 'test',
        email: 'student@example.com',
        expiresAt: now.subtract(const Duration(seconds: 1)),
      );
      await openVerification(tester, repository, challenge, now: () => now);
      expect(find.text('00:00'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '123');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(repository.calls, 0);
      expect(find.text('Altı haneli doğrulama kodunu girin.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(repository.calls, 1);
      expect(find.text(ResetUnavailable.message), findsOneWidget);
      expect(resendButton(tester).onPressed, isNotNull);
    },
  );

  testWidgets('Verification resynchronizes deadlines after backgrounding', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 29, 12);
    final repository = SpyRepository();
    final challenge = ResetChallenge(
      id: 'test',
      email: 'student@example.com',
      expiresAt: now.add(const Duration(minutes: 1)),
      resendAvailableAt: now.add(const Duration(seconds: 30)),
    );
    await openVerification(tester, repository, challenge, now: () => now);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(minutes: 2));
    await tester.pump(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('00:00'), findsOneWidget);
    expect(resendButton(tester).onPressed, isNotNull);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(repository.calls, 0);
  });

  testWidgets('Verification restarts timing when its challenge changes', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 29, 12);
    DateTime clock() => now;
    final repository = SpyRepository();
    await openVerification(
      tester,
      repository,
      ResetChallenge(
        id: 'old',
        email: 'student@example.com',
        expiresAt: now.add(const Duration(seconds: 60)),
      ),
      now: clock,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: EmailVerificationScreen(
          repository: repository,
          challenge: ResetChallenge(
            id: 'new',
            email: 'student@example.com',
            resendAvailableAt: now.add(const Duration(seconds: 2)),
          ),
          now: clock,
        ),
      ),
    );
    expect(find.text('Süre bilgisi yok.'), findsOneWidget);
    expect(resendButton(tester).onPressed, isNull);
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(resendButton(tester).onPressed, isNotNull);
  });

  testWidgets(
    'Verification resend is guarded and adopts returned challenge deadlines',
    (tester) async {
      var now = DateTime.utc(2026, 10, 29, 12);
      final pending = Completer<ResetChallenge>();
      const oldChallenge = ResetChallenge(
        id: 'old',
        email: 'student@example.com',
      );
      final repository =
          SpyRepository()
            ..resendHandler = (challenge) {
              expect(identical(challenge, oldChallenge), isTrue);
              return pending.future;
            };
      await openVerification(tester, repository, oldChallenge, now: () => now);
      await tester.enterText(find.byType(TextFormField), '123456');
      final resend = resendButton(tester).onPressed!;
      final done =
          tester.widget<TextField>(find.byType(TextField)).onSubmitted!;
      resend();
      resend();
      done('123456');
      await tester.pump();
      expect(repository.calls, 1);
      expect(resendButton(tester).onPressed, isNull);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      final replacement = ResetChallenge(
        id: 'replacement',
        email: 'student@example.com',
        expiresAt: now.add(const Duration(minutes: 2)),
        resendAvailableAt: now.add(const Duration(seconds: 10)),
      );
      pending.complete(replacement);
      await tester.pumpAndSettle();
      final screen = tester.widget<EmailVerificationScreen>(
        find.byType(EmailVerificationScreen),
      );
      expect(identical(screen.challenge, replacement), isTrue);
      expect(identical(screen.repository, repository), isTrue);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('02:00'), findsOneWidget);
      expect(resendButton(tester).onPressed, isNull);
      now = now.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      expect(resendButton(tester).onPressed, isNotNull);
      expect(find.text('01:50'), findsOneWidget);
      expect(repository.calls, 1);
    },
  );

  for (final entry
      in {
        ResetCodeFailure.invalidCode:
            'Doğrulama kodu hatalı. Kodu kontrol edin.',
        ResetCodeFailure.expiredCode:
            'Sunucu kodun süresinin dolduğunu bildirdi. Yeni kod isteyin.',
        ResetCodeFailure.tooManyAttempts:
            'Sunucu deneme sınırına ulaşıldığını bildirdi. Lütfen daha sonra tekrar deneyin.',
      }.entries) {
    testWidgets('Verification distinguishes server failure ${entry.key.name}', (
      tester,
    ) async {
      final repository = SpyRepository();
      repository.verifyHandler = (_, _) => Future<ResetGrant>.error(entry.key);
      repository.resendHandler = (_) => Future<ResetChallenge>.error(entry.key);
      await openVerification(
        tester,
        repository,
        const ResetChallenge(id: 'test', email: 'student@example.com'),
      );
      await tester.enterText(find.byType(TextFormField), '123456');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(NewPasswordScreen), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.ensureVisible(find.text('Yeniden Gönder'));
      await tester.tap(find.text('Yeniden Gönder'));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(repository.calls, 2);
      expect(resendButton(tester).onPressed, isNotNull);
    });
  }

  testWidgets(
    'Verification forwards only a controlled service grant to new password',
    (tester) async {
      final pending = Completer<ResetGrant>();
      const challenge = ResetChallenge(
        id: 'test',
        email: 'student@example.com',
      );
      const grant = ResetGrant(token: 'test-only-grant');
      final repository =
          SpyRepository()
            ..verifyHandler = (received, code) {
              expect(identical(received, challenge), isTrue);
              expect(code, '123456');
              return pending.future;
            };
      await openVerification(tester, repository, challenge);
      await tester.enterText(find.byType(TextFormField), '123456');
      final submit =
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!;
      submit();
      submit();
      await tester.pump();
      expect(repository.calls, 1);
      expect(find.byType(NewPasswordScreen), findsNothing);
      pending.complete(grant);
      await tester.pumpAndSettle();
      final screen = tester.widget<NewPasswordScreen>(
        find.byType(NewPasswordScreen),
      );
      expect(identical(screen.grant, grant), isTrue);
      expect(identical(screen.repository, repository), isTrue);
    },
  );

  for (final succeeds in [false, true]) {
    testWidgets(
      'Verification cleans timers and ignores resend after disposal (success: $succeeds)',
      (tester) async {
        var now = DateTime.utc(2026, 10, 29, 12);
        final pending = Completer<ResetChallenge>();
        final repository =
            SpyRepository()..resendHandler = (_) => pending.future;
        await openVerification(
          tester,
          repository,
          ResetChallenge(
            id: 'test',
            email: 'student@example.com',
            expiresAt: now.add(const Duration(minutes: 1)),
          ),
          now: () => now,
        );
        final resend = resendButton(tester).onPressed!;
        final submit =
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!;
        resend();
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        if (succeeds) {
          pending.complete(
            const ResetChallenge(id: 'late', email: 'student@example.com'),
          );
        } else {
          pending.completeError(StateError('controlled test failure'));
        }
        now = now.add(const Duration(minutes: 2));
        await tester.pump(const Duration(minutes: 2));
        resend();
        submit();
        await tester.pump();
        expect(repository.calls, 1);
        expect(find.byType(EmailVerificationScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  Future<void> openForgot(WidgetTester tester, SpyRepository repository) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ForgotPasswordScreen(repository: repository),
      ),
    );
  }

  testWidgets('Forgot rejects malformed email without calling the service', (
    tester,
  ) async {
    final repository = SpyRepository();
    await openForgot(tester, repository);
    await tester.enterText(find.byType(TextFormField), 'a b@example.com');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
    expect(repository.calls, 0);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'Forgot locks email and duplicate submissions, clears stale errors, and retries',
    (tester) async {
      final pending = Completer<ResetChallenge>();
      final requestedEmails = <String>[];
      final repository =
          SpyRepository()
            ..requestHandler = (email) {
              requestedEmails.add(email);
              return pending.future;
            };
      await openForgot(tester, repository);
      await tester.enterText(
        find.byType(TextFormField),
        ' student@example.com ',
      );
      await tester.ensureVisible(find.byType(FilledButton));
      final submit =
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!;
      final done =
          tester.widget<TextField>(find.byType(TextField)).onSubmitted!;
      submit();
      submit();
      done('student@example.com');
      await tester.pump();
      expect(repository.calls, 1);
      expect(requestedEmails, ['student@example.com']);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      tester
          .state<EditableTextState>(find.byType(EditableText))
          .updateEditingValue(
            const TextEditingValue(text: 'different@example.com'),
          );
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        ' student@example.com ',
      );
      pending.completeError(const ResetUnavailable());
      await tester.pumpAndSettle();
      expect(find.text(ResetUnavailable.message), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).readOnly,
        isFalse,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );

      await tester.enterText(find.byType(TextFormField), 'invalid');
      await tester.pump();
      expect(find.text(ResetUnavailable.message), findsNothing);
      expect(find.text('Geçerli bir e-posta adresi girin.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'corrected@example.com',
      );
      await tester.pump();
      expect(find.text('Geçerli bir e-posta adresi girin.'), findsNothing);
      repository.requestHandler = (email) {
        requestedEmails.add(email);
        return Future<ResetChallenge>.error(
          StateError('controlled test failure'),
        );
      };
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(requestedEmails, ['student@example.com', 'corrected@example.com']);
      expect(repository.calls, 2);
      expect(
        find.text('İşlem tamamlanamadı. Lütfen daha sonra tekrar deneyin.'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).readOnly,
        isFalse,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Forgot passes the exact controlled challenge and repository to verification',
    (tester) async {
      final pending = Completer<ResetChallenge>();
      final repository =
          SpyRepository()..requestHandler = (_) => pending.future;
      await openForgot(tester, repository);
      await tester.enterText(find.byType(TextFormField), 'student@example.com');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.byType(EmailVerificationScreen), findsNothing);
      const challenge = ResetChallenge(
        id: 'test-only-challenge',
        email: 'student@example.com',
      );
      pending.complete(challenge);
      await tester.pumpAndSettle();
      final verification = tester.widget<EmailVerificationScreen>(
        find.byType(EmailVerificationScreen),
      );
      expect(identical(verification.repository, repository), isTrue);
      expect(identical(verification.challenge, challenge), isTrue);
      expect(repository.calls, 1);
      Navigator.of(tester.element(find.byType(EmailVerificationScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).readOnly,
        isFalse,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final succeeds in [false, true]) {
    testWidgets(
      'Forgot ignores completion after disposal (success: $succeeds)',
      (tester) async {
        final pending = Completer<ResetChallenge>();
        final repository =
            SpyRepository()..requestHandler = (_) => pending.future;
        await openForgot(tester, repository);
        await tester.enterText(
          find.byType(TextFormField),
          'student@example.com',
        );
        await tester.ensureVisible(find.byType(FilledButton));
        final submit =
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!;
        submit();
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        if (succeeds) {
          pending.complete(
            const ResetChallenge(
              id: 'test-only-challenge',
              email: 'student@example.com',
            ),
          );
        } else {
          pending.completeError(StateError('controlled test failure'));
        }
        await tester.pumpAndSettle();
        submit();
        await tester.pump();
        expect(repository.calls, 1);
        expect(find.byType(EmailVerificationScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('Reset validation and email masking', () {
    for (final email in ['', ' ', 'invalid', 'a@b', 'a b@example.com']) {
      expect(PasswordResetValidators.email(email), isNotNull);
    }
    expect(PasswordResetValidators.email(' student@example.com '), isNull);
    for (final code in ['', '12345', '1234567', 'abcdef', '123 56']) {
      expect(PasswordResetValidators.code(code), isNotNull);
    }
    expect(PasswordResetValidators.code('123456'), isNull);
    for (final password in ['', '        ', '1234567']) {
      expect(PasswordResetValidators.password(password), isNotNull);
    }
    expect(PasswordResetValidators.password('12345678'), isNull);
    expect(PasswordResetValidators.confirmation('', '12345678'), isNotNull);
    expect(
      PasswordResetValidators.confirmation('different', '12345678'),
      isNotNull,
    );
    expect(
      PasswordResetValidators.confirmation('12345678', '12345678'),
      isNull,
    );
    expect(
      PasswordResetValidators.maskEmail('student@example.com'),
      's***@example.com',
    );
    expect(
      PasswordResetValidators.maskEmail('a@example.com'),
      'a***@example.com',
    );
    expect(PasswordResetValidators.maskEmail('invalid'), '***');
  });

  test(
    'Unavailable repository never returns a challenge, grant or update success',
    () async {
      const repository = UnavailablePasswordResetRepository();
      const challenge = ResetChallenge(
        id: 'test',
        email: 'student@example.com',
      );
      const grant = ResetGrant(token: 'test');
      await expectLater(
        repository.requestCode(challenge.email),
        throwsA(isA<ResetUnavailable>()),
      );
      await expectLater(
        repository.resendCode(challenge),
        throwsA(isA<ResetUnavailable>()),
      );
      await expectLater(
        repository.verifyCode(challenge, '123456'),
        throwsA(isA<ResetUnavailable>()),
      );
      await expectLater(
        repository.updatePassword(grant, '12345678'),
        throwsA(isA<ResetUnavailable>()),
      );
    },
  );

  testWidgets(
    'Login opens reset; unavailable API prevents advancement; both back actions work',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.ensureVisible(find.text('Şifremi Unuttum'));
      await tester.tap(find.text('Şifremi Unuttum'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Doğrulama Kodu Gönder'));
      await tester.tap(find.text('Doğrulama Kodu Gönder'));
      await tester.pump();
      expect(find.text('E-posta adresinizi girin.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'student@example.com');
      await tester.ensureVisible(find.text('Doğrulama Kodu Gönder'));
      await tester.tap(find.text('Doğrulama Kodu Gönder'));
      await tester.pumpAndSettle();
      expect(find.text(ResetUnavailable.message), findsOneWidget);
      expect(find.byType(EmailVerificationScreen), findsNothing);
      expect(find.byType(NewPasswordScreen), findsNothing);
      await tester.ensureVisible(find.text('Giriş Ekranına Dön'));
      await tester.tap(find.text('Giriş Ekranına Dön'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.ensureVisible(find.text('Şifremi Unuttum'));
      await tester.tap(find.text('Şifremi Unuttum'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Geri'));
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  testWidgets('Forgot preview cannot call even an injected repository', (
    tester,
  ) async {
    final spy = SpyRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ForgotPasswordScreen(preview: true, repository: spy),
      ),
    );
    await tester.enterText(find.byType(TextFormField), 'student@example.com');
    await tester.ensureVisible(find.text('Doğrulama Kodu Gönder'));
    await tester.tap(find.text('Doğrulama Kodu Gönder'));
    await tester.pumpAndSettle();
    expect(spy.calls, 0);
    expect(find.textContaining('Önizleme:'), findsOneWidget);
    expect(find.byType(EmailVerificationScreen), findsNothing);
  });

  testWidgets(
    'OTP native editor supports paste, numeric filtering, length, deletion and selection',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Form(child: OtpCodeField(controller: controller)),
          ),
        ),
      );
      await tester.showKeyboard(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), '12a34567');
      await tester.pump();
      expect(controller.text, '123456');
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '12345',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      await tester.pump();
      expect(controller.text, '12345');
      expect(controller.selection.baseOffset, 5);
      await tester.showKeyboard(find.byType(TextFormField));
      // Native paste uses the same editing-value channel as keyboard input.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '654321',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      await tester.pump();
      expect(controller.text, '654321');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);
      expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
      expect(tester.takeException(), isNull);
    },
  );

  for (final selection in ['forgot', 'verify', 'reset']) {
    testWidgets(
      '$selection preview fits small screen and keyboard, returns to login',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            onGenerateRoute:
                (_) => MaterialPageRoute<void>(
                  builder: (_) => const LoginScreen(),
                ),
            onGenerateInitialRoutes:
                (_) => [
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                  MaterialPageRoute<void>(
                    builder: (_) => PasswordResetPreview.screenFor(selection)!,
                  ),
                ],
          ),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        if (selection == 'forgot') {
          await tester.enterText(fields.first, 'student@example.com');
        } else if (selection == 'verify') {
          await tester.enterText(fields.first, '123456');
          expect(find.text('s***@example.com'), findsNothing);
          expect(find.text('o***@example.com'), findsOneWidget);
          await tester.pump(const Duration(seconds: 5));
          expect(find.text('01:00'), findsNothing);
          expect(find.text('Süre bilgisi yok.'), findsOneWidget);
          await tester.ensureVisible(find.text('Yeniden Gönder'));
          await tester.tap(find.text('Yeniden Gönder'));
          await tester.pump();
          expect(find.text('Önizleme: E-posta gönderilmez.'), findsOneWidget);
        } else {
          await tester.enterText(fields.first, '12345678');
          await tester.enterText(fields.last, 'different');
          await tester.ensureVisible(find.text('Şifremi Güncelle'));
          await tester.tap(find.text('Şifremi Güncelle'));
          await tester.pump();
          expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
          await tester.enterText(fields.last, '12345678');
          await tester.ensureVisible(
            find.byTooltip('YENİ ŞİFRE: Şifreyi göster'),
          );
          await tester.tap(find.byTooltip('YENİ ŞİFRE: Şifreyi göster'));
          await tester.pump();
          expect(
            tester.widget<TextField>(find.byType(TextField).first).obscureText,
            isFalse,
          );
          expect(
            tester.widget<TextField>(find.byType(TextField).last).obscureText,
            isTrue,
          );
        }
        final button =
            selection == 'forgot'
                ? 'Doğrulama Kodu Gönder'
                : selection == 'verify'
                ? 'Kodu Doğrula'
                : 'Şifremi Güncelle';
        await tester.ensureVisible(find.text(button));
        await tester.tap(find.text(button));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Önizleme: E-posta gönderilmez, kod doğrulanmaz'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byTooltip('Geri'));
        await tester.tap(find.byTooltip('Geri'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
      },
    );
  }
  test('Unknown preview selection does not open any screen', () {
    expect(PasswordResetPreview.screenFor('unknown'), isNull);
  });
}
