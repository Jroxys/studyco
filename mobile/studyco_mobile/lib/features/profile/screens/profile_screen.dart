import 'package:flutter/material.dart';
import '../../home/widgets/home_bottom_navigation.dart';
import '../models/profile_destination.dart';
import '../models/user_profile.dart';
import '../widgets/profile_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.onDestination,
    this.onOpenSection,
  });
  final UserProfile user;
  final ValueChanged<int> onDestination;
  final ValueChanged<ProfileDestination>? onOpenSection;

  void _open(BuildContext context, ProfileDestination destination) {
    if (onOpenSection != null) {
      onOpenSection!(destination);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${destination.label}: Bu bölüm henüz hazır değil.'),
        ),
      );
  }

  Widget _heading(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: .4,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 46,
      centerTitle: true,
      title: Image.asset(
        'assets/images/studyco_logo.png',
        height: 32,
        fit: BoxFit.contain,
        semanticLabel: 'StudyCo',
        errorBuilder: (_, _, _) => const Text('StudyCo'),
      ),
    ),
    bottomNavigationBar: HomeBottomNavigation(
      selectedIndex: 3,
      onSelected: (index) {
        if (index != 3) onDestination(index);
      },
    ),
    body: SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Keep the content in natural flow, with modest extra room on wider phones.
          final breathingRoom = ((constraints.maxWidth - 390) / 22).clamp(
            0.0,
            1.0,
          );
          final gap = 2 + breathingRoom * 6;
          final rowGap = 3 + breathingRoom * 3;
          final rowHeight = 56 + breathingRoom * 2;
          final verticalPadding = .5 + breathingRoom * 3.5;
          final cardExpansion = ((constraints.maxHeight - 680) / 16).clamp(
            0.0,
            8.0,
          );
          final activities = <(ProfileDestination, IconData)>[
            (ProfileDestination.posts, Icons.article_outlined),
            (ProfileDestination.applications, Icons.send_outlined),
            (ProfileDestination.incomingApplications, Icons.inbox_outlined),
            (ProfileDestination.reviews, Icons.star_outline_rounded),
          ];
          return SingleChildScrollView(
            key: const ValueKey('profile-scroll'),
            padding: EdgeInsets.fromLTRB(
              constraints.maxWidth <= 360 ? 12 : 16,
              2,
              constraints.maxWidth <= 360 ? 12 : 16,
              gap,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Profilim',
                        key: ValueKey('profile-title'),
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ProfileIdentityCard(
                      user: user,
                      extraPadding: cardExpansion,
                      extraVerticalPadding: verticalPadding,
                      onEdit: () => _open(context, ProfileDestination.edit),
                    ),
                    SizedBox(height: gap),
                    ProfileStatCard(
                      key: const ValueKey('profile-rating'),
                      extraPadding: cardExpansion,
                      extraVerticalPadding: verticalPadding,
                      title: 'Değerlendirme Puanım',
                      icon: Icons.star_outline_rounded,
                      caption: 'Değerlendirme sayısı: —',
                      onTap: () => _open(context, ProfileDestination.reviews),
                    ),
                    SizedBox(height: rowGap),
                    ProfileStatCard(
                      key: const ValueKey('profile-tokens'),
                      extraPadding: cardExpansion,
                      extraVerticalPadding: verticalPadding,
                      title: 'Tokenlarım',
                      icon: Icons.local_cafe_outlined,
                      caption: 'Bakiye bilgisi henüz mevcut değil.',
                      actionLabel: 'Token Yükle',
                      onTap: () => _open(context, ProfileDestination.tokens),
                    ),
                    SizedBox(height: gap),
                    _heading('Aktivitelerim'),
                    Column(
                      key: const ValueKey('profile-activities'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < activities.length; i++) ...[
                          if (i > 0) SizedBox(height: rowGap),
                          ProfileActionTile(
                            key: ValueKey('profile-${activities[i].$1.name}'),
                            label: activities[i].$1.label,
                            icon: activities[i].$2,
                            minHeight: rowHeight,
                            onTap: () => _open(context, activities[i].$1),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: gap),
                    _heading('HESAP'),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final item in <(ProfileDestination, IconData)>[
                          (
                            ProfileDestination.settings,
                            Icons.settings_outlined,
                          ),
                          (
                            ProfileDestination.support,
                            Icons.help_outline_rounded,
                          ),
                          (ProfileDestination.logout, Icons.logout_rounded),
                        ]) ...[
                          if (item.$1 != ProfileDestination.settings)
                            const SizedBox(width: 8),
                          Expanded(
                            child: ProfileActionTile(
                              key: ValueKey('profile-${item.$1.name}'),
                              label: item.$1.label,
                              icon: item.$2,
                              vertical: true,
                              minHeight: 64 + breathingRoom * 4,
                              destructive: item.$1 == ProfileDestination.logout,
                              onTap: () => _open(context, item.$1),
                            ),
                          ),
                        ],
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
  );
}
