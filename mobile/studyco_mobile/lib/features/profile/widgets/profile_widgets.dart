import 'package:flutter/material.dart';
import '../../../core/constants/app_university.dart';
import '../models/user_profile.dart';

class ProfilePanel extends StatelessWidget {
  const ProfilePanel({
    super.key,
    required this.child,
    this.onTap,
    this.tinted = false,
  });
  final Widget child;
  final VoidCallback? onTap;
  final bool tinted;
  @override
  Widget build(BuildContext context) => Material(
    color:
        tinted
            ? Color.alphaBlend(
              Theme.of(context).colorScheme.secondary.withValues(alpha: .1),
              Theme.of(context).colorScheme.surface,
            )
            : Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: child),
  );
}

class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    super.key,
    required this.user,
    required this.onEdit,
    this.extraPadding = 0,
    this.extraVerticalPadding = 0,
  });
  final UserProfile user;
  final VoidCallback onEdit;
  final double extraPadding;
  final double extraVerticalPadding;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initials =
        user.firstName
            .trim()
            .split(RegExp(r'\s+'))
            .where((part) => part.isNotEmpty)
            .take(2)
            .map((part) => part.characters.first)
            .join()
            .toUpperCase();
    return ProfilePanel(
      tinted: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 14 + extraPadding / 2,
          vertical: 10 + extraPadding + extraVerticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: colors.secondary.withValues(alpha: .2),
                  foregroundColor: colors.primary,
                  child:
                      initials.isEmpty
                          ? const Icon(Icons.person_outline)
                          : Text(
                            initials,
                            textScaler: TextScaler.noScaling,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.firstName,
                        key: const ValueKey('profile-name'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('profile-edit'),
                  tooltip: 'Profili Düzenle',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surface.withValues(alpha: .7),
                    foregroundColor: colors.primary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4 + extraPadding / 2),
            Text(
              user.department,
              key: const ValueKey('profile-department'),
              style: const TextStyle(
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              studyCoUniversityName,
              key: const ValueKey('profile-university'),
              style: TextStyle(
                fontSize: 12,
                height: 1.25,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileStatCard extends StatelessWidget {
  const ProfileStatCard({
    super.key,
    required this.title,
    required this.icon,
    required this.caption,
    this.value = '—',
    this.actionLabel,
    this.onTap,
    this.extraPadding = 0,
    this.extraVerticalPadding = 0,
  });
  final String title;
  final double extraPadding;
  final double extraVerticalPadding;
  final IconData icon;
  final String caption;
  final String value;
  final String? actionLabel;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ProfilePanel(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: 64 + (extraPadding + extraVerticalPadding) * 2,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12 + extraPadding / 2,
            vertical: 9 + extraPadding + extraVerticalPadding,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: colors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (actionLabel != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              actionLabel!,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 4 + extraPadding / 2),
                    Row(
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            caption,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileActionTile extends StatelessWidget {
  const ProfileActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.vertical = false,
    this.destructive = false,
    this.minHeight = 48,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool vertical;
  final bool destructive;
  final double minHeight;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = destructive ? colors.error : colors.primary;
    final text = Text(
      label,
      textAlign: vertical ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        color: color,
        fontSize: vertical ? 12 : 14,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
    );
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: vertical ? 8 : 12,
          vertical: vertical ? 5 : 6,
        ),
        child:
            vertical
                ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 19, color: color),
                    const SizedBox(height: 3),
                    text,
                  ],
                )
                : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.secondary.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: text),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
      ),
    );
    return ProfilePanel(onTap: onTap, child: content);
  }
}
