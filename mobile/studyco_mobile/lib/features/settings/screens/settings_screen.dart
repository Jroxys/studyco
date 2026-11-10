import 'package:flutter/material.dart';
import '../../auth/screens/password_reset_screens.dart';
import '../../auth/widgets/session_logout_scope.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/widgets/profile_repository_scope.dart';
import '../../profile/widgets/profile_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.user});

  final UserProfile user;

  String? _knownEmail(BuildContext context) {
    if (user.id?.trim().isNotEmpty != true) return null;
    final email = ProfileRepositoryScope.currentOf(context, user).email?.trim();
    return email == null || email.isEmpty ? null : email;
  }

  Future<String?> _loadEmail(BuildContext context) async {
    final known = _knownEmail(context);
    if (known != null) return known;
    final source = ProfileRepositoryScope.forUser(context, user);
    if (source == null) return null;
    final profile = await source.fetchProfile();
    if (profile.id != user.id || source.userId != user.id) return null;
    final email = profile.email?.trim();
    return email == null || email.isEmpty ? null : email;
  }

  void _openPasswordReset(BuildContext context) {
    final email = _knownEmail(context);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (routeContext) => ForgotPasswordScreen(
              initialEmail: email,
              onReturn: () => Navigator.of(routeContext).pop(),
            ),
      ),
    );
  }

  void _showEmail(BuildContext context) {
    final email = _loadEmail(context);
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            scrollable: true,
            title: const Text('E-posta Adresim'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kayıtlı e-posta adresi',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                FutureBuilder<String?>(
                  future: email,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LinearProgressIndicator(
                        semanticsLabel: 'E-posta yükleniyor',
                      );
                    }
                    return Text(
                      snapshot.hasError
                          ? 'E-posta bilgisi alınamadı.'
                          : snapshot.data ??
                              'Kayıtlı e-posta bilgisi bulunmuyor.',
                    );
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'E-posta adresi şu anda uygulama üzerinden değiştirilemiyor.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ],
          ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            scrollable: true,
            title: const Text('StudyCo'),
            content: const Text(
              'StudyCo, Sivas Cumhuriyet Üniversitesi öğrencilerinin bilgi ve becerilerini paylaşarak birbirlerine destek olmasını amaçlayan bir öğrenci platformudur.\n\n'
              'Öğrenciler ders ilanları oluşturabilir, diğer öğrencilerin ilanlarına başvurabilir, birlikte çalışma fırsatları bulabilir ve tamamlanan derslerin ardından birbirlerini değerlendirebilir.\n\n'
              'StudyCo ile öğrenmek ve öğretmek daha kolay!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ],
          ),
    );
  }

  void _showDeletion(BuildContext context) {
    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            scrollable: true,
            title: Text(
              'Hesabımı Sil',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hesabını silersen profil bilgilerin ve hesabına bağlı veriler, uygulamanın veri saklama kurallarına göre kalıcı olarak silinir veya anonimleştirilir. Bu işlem geri alınamaz.',
                ),
                SizedBox(height: 12),
                Text('Hesap silme işlemi henüz kullanılamıyor.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Vazgeç'),
              ),
              const FilledButton(onPressed: null, child: Text('Hesabımı Sil')),
            ],
          ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> rows) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 8),
        ProfilePanel(
          backgroundColor: colors.onPrimary,
          child: Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: colors.outlineVariant,
                  ),
                rows[index],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool destructive = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: destructive ? colors.error : colors.secondary),
      title: Text(
        label,
        style: TextStyle(
          color: destructive ? colors.error : colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: colors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ayarlar')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Hesabını ve uygulama bilgilerini yönet.'),
                const SizedBox(height: 24),
                _section(context, 'HESAP GÜVENLİĞİ', [
                  _row(
                    context,
                    'Şifremi Değiştir',
                    Icons.lock_outline,
                    () => _openPasswordReset(context),
                  ),
                  _row(
                    context,
                    'E-posta Adresim',
                    Icons.email_outlined,
                    () => _showEmail(context),
                  ),
                ]),
                const SizedBox(height: 20),
                _section(context, 'UYGULAMA', [
                  _row(
                    context,
                    'StudyCo Hakkında',
                    Icons.info_outline,
                    () => _showAbout(context),
                  ),
                ]),
                const SizedBox(height: 20),
                _section(context, 'HESAP YÖNETİMİ', [
                  _row(
                    context,
                    'Çıkış Yap',
                    Icons.logout_rounded,
                    () => SessionLogoutScope.confirm(
                      context,
                      endSession: SessionLogoutScope.forUser(context, user.id),
                    ),
                  ),
                  _row(
                    context,
                    'Hesabımı Sil',
                    Icons.delete_outline,
                    () => _showDeletion(context),
                    destructive: true,
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
