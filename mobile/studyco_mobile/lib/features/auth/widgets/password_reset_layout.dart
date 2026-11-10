import 'package:flutter/material.dart';
import '../validation/password_reset_validators.dart';
import 'auth_form_widgets.dart';

class MaskedEmail extends StatelessWidget {
  const MaskedEmail({super.key, required this.email});
  final String email;
  @override
  Widget build(BuildContext context) => Text(
    PasswordResetValidators.maskEmail(email),
    textAlign: TextAlign.center,
    style: TextStyle(
      color: Theme.of(context).colorScheme.secondary,
      fontWeight: FontWeight.w700,
    ),
  );
}

class PasswordResetLayout extends StatelessWidget {
  const PasswordResetLayout({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.preview = false,
    this.balanceVertically = false,
    this.onReturn,
  });
  final String title;
  final String description;
  final Widget child;
  final bool preview;
  final bool balanceVertically;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuthBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Geri',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Center(
                  child: Image.asset(
                    'assets/images/studyco_logo.png',
                    width: 220,
                    semanticLabel: 'StudyCo logosu',
                  ),
                ),
                const SizedBox(height: 24),
                if (balanceVertically) const Spacer(),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(description, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                AuthFormCard(compact: compact, child: child),
                const SizedBox(height: 12),
                if (balanceVertically) const Spacer(flex: 2),
                if (preview)
                  const Text(
                    'Tasarım önizlemesi • İşlemler devre dışı',
                    textAlign: TextAlign.center,
                  ),
                TextButton(
                  onPressed:
                      onReturn ??
                      () => Navigator.of(
                        context,
                      ).popUntil((route) => route.isFirst),
                  child: Text(
                    onReturn == null ? 'Giriş Ekranına Dön' : 'Ayarlara Dön',
                  ),
                ),
              ],
            );
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 28,
                vertical: 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 420,
                    minHeight:
                        balanceVertically
                            ? (constraints.maxHeight - 32).clamp(
                              0.0,
                              double.infinity,
                            )
                            : 0,
                  ),
                  child:
                      balanceVertically
                          ? IntrinsicHeight(child: content)
                          : content,
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
