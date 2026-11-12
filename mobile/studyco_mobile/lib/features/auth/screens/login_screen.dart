import 'package:flutter/material.dart';

import 'register_screen.dart';
import 'password_reset_screens.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'E-posta adresinizi girin.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Geçerli bir e-posta adresi girin.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Şifrenizi girin.';
    }
    return null;
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!mounted || _busy) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      // Keep the current synchronous fallback in the same guarded async flow.
      await Future<void>.sync(() {
        FocusScope.of(context).unfocus();
        _showMessage('Giriş şu anda kullanılamıyor.');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildLabeledField({required String label, required Widget field}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(label: label, child: field),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final placeholderStyle = TextStyle(
      color: colors.onSurfaceVariant.withValues(alpha: 0.55),
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                colors.secondary.withValues(alpha: 0.10),
                colors.surface,
              ),
              colors.onPrimary,
            ],
            stops: const [0, 0.85],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.9, -0.85),
              radius: 1.1,
              colors: [
                colors.secondary.withValues(alpha: 0.12),
                colors.secondary.withValues(alpha: 0),
              ],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.9, -0.45),
                radius: 0.9,
                colors: [
                  colors.tertiary.withValues(alpha: 0.07),
                  colors.tertiary.withValues(alpha: 0),
                ],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;
                  final horizontalPadding = compact ? 20.0 : 28.0;
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 64).clamp(
                          0.0,
                          double.infinity,
                        ),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Image.asset(
                                  'assets/images/studyco_logo.png',
                                  width: 240,
                                  fit: BoxFit.contain,
                                  semanticLabel: 'StudyCo logosu',
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Hoş geldin!',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Container(
                                padding: EdgeInsets.all(compact ? 20 : 26),
                                decoration: BoxDecoration(
                                  color: colors.onPrimary,
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(color: Color(0xFFD7E3E1)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.primary.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 32,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: AutofillGroup(
                                  child: Form(
                                    key: _formKey,
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildLabeledField(
                                          label: 'E-POSTA ADRESİ',
                                          field: TextFormField(
                                            controller: _emailController,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            textInputAction:
                                                TextInputAction.next,
                                            textCapitalization:
                                                TextCapitalization.none,
                                            autocorrect: false,
                                            autofillHints: const [
                                              AutofillHints.username,
                                            ],
                                            validator: _validateEmail,
                                            decoration: InputDecoration(
                                              hintText: 'ornek@gmail.com',
                                              hintStyle: placeholderStyle,
                                              prefixIcon: const Icon(
                                                Icons.email_outlined,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        _buildLabeledField(
                                          label: 'ŞİFRE',
                                          field: Transform.translate(
                                            offset: const Offset(0, -4),
                                            child: TextFormField(
                                              controller: _passwordController,
                                              obscureText: _obscurePassword,
                                              autocorrect: false,
                                              enableSuggestions: false,
                                              autofillHints: const [
                                                AutofillHints.password,
                                              ],
                                              textInputAction:
                                                  TextInputAction.done,
                                              onFieldSubmitted:
                                                  (_) => _submit(),
                                              validator: _validatePassword,
                                              decoration: InputDecoration(
                                                hintText: 'Şifrenizi girin',
                                                hintStyle: placeholderStyle,
                                                prefixIcon: const Icon(
                                                  Icons.lock_outline,
                                                ),
                                                suffixIcon: ClipOval(
                                                  child: IconButton(
                                                    tooltip:
                                                        _obscurePassword
                                                            ? 'Şifreyi göster'
                                                            : 'Şifreyi gizle',
                                                    onPressed: () {
                                                      setState(() {
                                                        _obscurePassword =
                                                            !_obscurePassword;
                                                      });
                                                    },
                                                    icon: Icon(
                                                      _obscurePassword
                                                          ? Icons
                                                              .visibility_off_outlined
                                                          : Icons
                                                              .visibility_outlined,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            style: TextButton.styleFrom(
                                              foregroundColor: colors.tertiary,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 0,
                                                    vertical: 12,
                                                  ),
                                            ),
                                            onPressed:
                                                () => Navigator.of(
                                                  context,
                                                ).push<void>(
                                                  MaterialPageRoute(
                                                    builder:
                                                        (_) =>
                                                            const ForgotPasswordScreen(),
                                                  ),
                                                ),
                                            child: const Text(
                                              'Şifremi Unuttum',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        FilledButton(
                                          onPressed: _busy ? null : _submit,
                                          child: const Text('Giriş Yap'),
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
                                    'Hesabın yok mu?',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 16,
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: colors.secondary,
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    onPressed:
                                        () => Navigator.of(context).push<void>(
                                          MaterialPageRoute(
                                            builder:
                                                (_) => const RegisterScreen(),
                                          ),
                                        ),
                                    child: const Text('Kayıt Ol'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
