import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/password_reset_repository.dart';
import '../validation/password_reset_validators.dart';
import '../widgets/auth_form_widgets.dart';
import '../widgets/otp_code_field.dart';
import '../widgets/password_reset_layout.dart';

// State remains local to each route; transport and validation are independent.
abstract class _ResetState<T extends StatefulWidget> extends State<T> {
  final formKey = GlobalKey<FormState>();
  bool busy = false;
  String? message;

  Future<void> perform(bool preview, Future<void> Function() action) async {
    if (!formKey.currentState!.validate() || busy) return;
    FocusScope.of(context).unfocus();
    if (preview) {
      setState(
        () =>
            message =
                'Önizleme: E-posta gönderilmez, kod doğrulanmaz ve şifre değiştirilmez.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } on ResetUnavailable {
      if (mounted) setState(() => message = ResetUnavailable.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              message =
                  'İşlem tamamlanamadı. Lütfen daha sonra tekrar deneyin.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget form(List<Widget> children) => Form(
    key: formKey,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...children,
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Semantics(liveRegion: true, child: Text(message!)),
          ),
        if (busy) const LinearProgressIndicator(),
      ],
    ),
  );
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.repository = const UnavailablePasswordResetRepository(),
    this.preview = false,
    this.initialEmail,
    this.onReturn,
  });
  final PasswordResetRepository repository;
  final bool preview;
  final String? initialEmail;
  final VoidCallback? onReturn;
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends _ResetState<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!mounted || busy) return;
    final email = _email.text.trim();
    await perform(kDebugMode && widget.preview, () async {
      final challenge = await widget.repository.requestCode(email);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder:
              (_) => EmailVerificationScreen(
                repository: widget.repository,
                challenge: challenge,
              ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => PasswordResetLayout(
    title: 'Şifremi Unuttum',
    balanceVertically: true,
    description: 'Şifreni yenilemek için e-posta adresini gir.',
    onReturn: widget.onReturn,
    preview: kDebugMode && widget.preview,
    child: form([
      AuthLabeledField(
        label: 'E-POSTA ADRESİ',
        field: TextFormField(
          controller: _email,
          readOnly: busy,
          onChanged: (_) {
            if (message != null) setState(() => message = null);
          },
          validator: PasswordResetValidators.email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          onFieldSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: 'ornek@gmail.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: busy ? null : _submit,
        child: const Text('Doğrulama Kodu Gönder'),
      ),
    ]),
  );
}

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.repository,
    required this.challenge,
    this.now,
  });
  const EmailVerificationScreen.preview({super.key, this.now})
    : repository = const UnavailablePasswordResetRepository(),
      challenge = null;
  final PasswordResetRepository repository;
  final ResetChallenge? challenge;
  // Injectable clock for deterministic timing tests; production uses wall time.
  final DateTime Function()? now;
  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends _ResetState<EmailVerificationScreen>
    with WidgetsBindingObserver {
  final _code = TextEditingController();
  Timer? _timer;
  late DateTime _currentTime;
  bool get _preview => kDebugMode && widget.challenge == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant EmailVerificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challenge != widget.challenge ||
        oldWidget.now != widget.now) {
      _restartTimer();
    }
  }

  int? _secondsUntil(DateTime? deadline) {
    if (deadline == null) return null;
    final remaining = deadline.difference(_currentTime).inMicroseconds;
    if (remaining <= 0) return 0;
    return (remaining + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
  }

  bool get _waitingToResend =>
      (_secondsUntil(widget.challenge?.resendAvailableAt) ?? 0) > 0;
  bool get _hasFutureDeadline =>
      (_secondsUntil(widget.challenge?.expiresAt) ?? 0) > 0 || _waitingToResend;

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    _currentTime = (widget.now ?? DateTime.now)();
    if (!_hasFutureDeadline) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _currentTime = (widget.now ?? DateTime.now)());
      if (!_hasFutureDeadline) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) setState(_restartTimer);
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  String _formatSeconds(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';

  String _failureMessage(ResetCodeFailure failure) => switch (failure) {
    ResetCodeFailure.invalidCode => 'Doğrulama kodu hatalı. Kodu kontrol edin.',
    ResetCodeFailure.expiredCode =>
      'Sunucu kodun süresinin dolduğunu bildirdi. Yeni kod isteyin.',
    ResetCodeFailure.tooManyAttempts =>
      'Sunucu deneme sınırına ulaşıldığını bildirdi. Lütfen daha sonra tekrar deneyin.',
  };

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!mounted || busy) return;
    await perform(_preview, () async {
      final challenge = widget.challenge;
      if (challenge == null) throw const ResetUnavailable();
      final ResetGrant grant;
      try {
        grant = await widget.repository.verifyCode(challenge, _code.text);
      } on ResetCodeFailure catch (failure) {
        if (mounted) setState(() => message = _failureMessage(failure));
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder:
              (_) => NewPasswordScreen(
                repository: widget.repository,
                grant: grant,
              ),
        ),
      );
    });
  }

  Future<void> _resend() async {
    if (!mounted || busy) return;
    // Read the clock again so a delayed timer tick never extends a server deadline.
    setState(() => _currentTime = (widget.now ?? DateTime.now)());
    if (_waitingToResend) return;
    if (_preview || widget.challenge == null) {
      setState(() => message = 'Önizleme: E-posta gönderilmez.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final challenge = await widget.repository.resendCode(widget.challenge!);
      if (!mounted) return;
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder:
              (_) => EmailVerificationScreen(
                repository: widget.repository,
                challenge: challenge,
                now: widget.now,
              ),
        ),
      );
    } on ResetCodeFailure catch (failure) {
      if (mounted) setState(() => message = _failureMessage(failure));
    } on ResetUnavailable {
      if (mounted) setState(() => message = ResetUnavailable.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              message =
                  'İşlem tamamlanamadı. Lütfen daha sonra tekrar deneyin.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PasswordResetLayout(
    title: 'E-posta Doğrulama',
    description: 'E-posta adresine ait altı haneli doğrulama kodunu gir.',
    preview: _preview,
    child: form([
      MaskedEmail(email: widget.challenge?.email ?? 'ogrenci@example.com'),
      const SizedBox(height: 20),
      OtpCodeField(controller: _code, onSubmitted: (_) => _submit()),
      const SizedBox(height: 12),
      Text(switch (_secondsUntil(widget.challenge?.expiresAt)) {
        final seconds? => _formatSeconds(seconds),
        null => 'Süre bilgisi yok.',
      }, textAlign: TextAlign.center),
      Text(
        _waitingToResend
            ? 'Yeniden gönderim: ${_formatSeconds(_secondsUntil(widget.challenge?.resendAvailableAt)!)}'
            : 'Kod geçerliliğini sunucu kontrol eder.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: busy ? null : _submit,
        child: const Text('Kodu Doğrula'),
      ),
      const SizedBox(height: 12),
      const Text('Kod gelmedi mi?', textAlign: TextAlign.center),
      TextButton(
        onPressed: busy || _waitingToResend ? null : _resend,
        child: const Text('Yeniden Gönder'),
      ),
    ]),
  );
}

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({
    super.key,
    required this.repository,
    required this.grant,
  });
  const NewPasswordScreen.preview({super.key})
    : repository = const UnavailablePasswordResetRepository(),
      grant = null;
  final PasswordResetRepository repository;
  final ResetGrant? grant;
  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends _ResetState<NewPasswordScreen> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool get _preview => kDebugMode && widget.grant == null;
  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _clearMessage(String _) {
    if (mounted && message != null) setState(() => message = null);
  }

  Future<void> _submit() async {
    if (!mounted || busy) return;
    final password = _password.text;
    await perform(_preview, () async {
      final grant = widget.grant;
      if (grant == null) throw const ResetUnavailable();
      try {
        await widget.repository.updatePassword(grant, password);
      } on ResetGrantFailure catch (failure) {
        if (mounted) {
          setState(
            () =>
                message = switch (failure) {
                  ResetGrantFailure.invalidGrant =>
                    'Doğrulama yetkisi geçersiz. Şifre sıfırlama işlemini yeniden başlatın.',
                  ResetGrantFailure.expiredGrant =>
                    'Doğrulama yetkisinin süresi dolmuş. Şifre sıfırlama işlemini yeniden başlatın.',
                },
          );
        }
        return;
      }
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) => PasswordResetLayout(
    title: 'Yeni Şifre Oluştur',
    description: 'En az 8 karakter içeren yeni bir şifre belirle.',
    preview: _preview,
    child: form([
      AuthPasswordField(
        controller: _password,
        readOnly: busy,
        label: 'YENİ ŞİFRE',
        validator: PasswordResetValidators.password,
        onChanged: (value) {
          _clearMessage(value);
          if (_confirmation.text.isNotEmpty) formKey.currentState?.validate();
        },
      ),
      const SizedBox(height: 20),
      AuthPasswordField(
        controller: _confirmation,
        readOnly: busy,
        onChanged: _clearMessage,
        label: 'ŞİFRE TEKRAR',
        hintText: 'Şifrenizi tekrar girin',
        validator:
            (value) =>
                PasswordResetValidators.confirmation(value, _password.text),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: busy ? null : _submit,
        child: const Text('Şifremi Güncelle'),
      ),
    ]),
  );
}
