import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../profile/models/user_profile.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.user,
    required this.onMessages,
    required this.onNotifications,
    required this.onProfile,
    this.isPreview = false,
  });
  final UserProfile user;
  final VoidCallback onMessages;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final bool isPreview;

  Widget _badge(
    BuildContext context,
    String label,
    IconData icon,
    int count,
    VoidCallback action,
  ) => IconButton(
    tooltip: label,
    onPressed: action,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    style: IconButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.primary,
    ),
    icon: SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          Positioned(left: 6, bottom: 3, child: Icon(icon, size: 28)),
          if (count > 0)
            Positioned(
              top: 0,
              right: 1,
              child: Semantics(
                label: '$count okunmamış',
                child: Badge(
                  backgroundColor:
                      label == 'Mesajlar'
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.secondary,
                  textColor: Theme.of(context).colorScheme.onPrimary,
                  label: Text(count > 99 ? '99+' : '$count'),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('home-top-bar'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              colors.secondary.withValues(alpha: 0.06),
              colors.surface,
            ),
            border: Border(
              bottom: BorderSide(color: colors.primary.withValues(alpha: 0.07)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset(
                  'assets/images/studyco_logo.png',
                  semanticLabel: 'StudyCo logosu',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'StudyCo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                    Text(
                      user.campus.toUpperCase(),
                      softWrap: true,
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.4,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              _badge(
                context,
                'Mesajlar',
                Icons.chat_bubble_outline,
                user.unreadMessages,
                onMessages,
              ),
              const SizedBox(width: 4),
              _badge(
                context,
                'Bildirimler',
                Icons.notifications_outlined,
                user.unreadNotifications,
                onNotifications,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Merhaba 👋',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        if (kDebugMode && isPreview) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Örnek veriler • Oturum açılmadı',
                            triggerMode: TooltipTriggerMode.tap,
                            child: Icon(
                              Icons.info_outline,
                              size: 14,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      user.firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.onPrimary,
                        border: Border.all(
                          color: colors.secondary.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: colors.secondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${user.university} • ${user.department}',
                              softWrap: true,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                tooltip: 'Profilim',
                onPressed: onProfile,
                style: IconButton.styleFrom(
                  minimumSize: const Size(52, 52),
                  backgroundColor: colors.secondary.withValues(alpha: 0.10),
                  side: BorderSide(
                    color: colors.secondary.withValues(alpha: 0.45),
                  ),
                ),
                icon: Icon(
                  Icons.person_outline,
                  color: colors.primary,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
