import '../../messages/widgets/conversation_navigation.dart';
import 'package:flutter/material.dart';
import '../../applications/screens/applications_screen.dart';
import '../../posts/domain/posts_repository.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/widgets/profile_widgets.dart';
import '../domain/notifications_repository.dart';
import '../models/study_notification.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.postsRepository,
  });

  final UserProfile user;
  final NotificationsRepository? repository;
  final PostsRepository postsRepository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  bool _loadFailed = false;
  bool _updating = false;
  bool _openingTarget = false;

  NotificationsRepository? get _source {
    final source = widget.repository;
    return widget.user.id?.trim().isNotEmpty == true &&
            source?.userId == widget.user.id
        ? source
        : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      // Let the route mount before an adapter can notify Home listeners.
      await Future<void>.value();
      if (mounted) await _source?.refresh();
    } catch (_) {
      if (mounted) _loadFailed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _update(Future<void> Function() action, String fallback) async {
    if (_updating || _loading) return false;
    setState(() => _updating = true);
    try {
      await action();
      return mounted;
    } on NotificationFailure catch (error) {
      if (mounted) _message(error.message);
      return false;
    } catch (_) {
      if (mounted) _message(fallback);
      return false;
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _open(StudyNotification item) async {
    if (_updating || _openingTarget) return;
    final source = _source;
    if (source == null || item.recipientId != widget.user.id) {
      _message('Bu bildirim hesabına ait değil.');
      return;
    }
    final matches = source.notifications.where(
      (entry) => entry.id == item.id && entry.recipientId == widget.user.id,
    );
    if (matches.isEmpty) {
      _message('Bu bildirim artık görüntülenemiyor.');
      return;
    }
    final current = matches.first;
    if (!current.isRead &&
        !await _update(
          () => source.markRead(current.id),
          'Bildirim okundu olarak işaretlenemedi. Tekrar deneyebilirsin.',
        )) {
      return;
    }
    if (!mounted || !identical(source, _source)) return;

    if (current.target == NotificationTarget.conversation) {
      _openingTarget = true;
      try {
        await ConversationNavigation.open(
          context,
          userId: widget.user.id,
          conversationId: current.targetId,
        );
      } finally {
        _openingTarget = false;
      }
      return;
    }
    final id = current.targetId;
    final applications = widget.postsRepository.applicationsRepository;
    if (id == null || id.trim().isEmpty || applications == null) {
      _message('Bildirimdeki başvuru bulunamadı.');
      return;
    }
    _openingTarget = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder:
              (_) => ApplicationsScreen(
                postsRepository: widget.postsRepository,
                repository: applications,
                user: widget.user,
                incoming:
                    current.target == NotificationTarget.incomingApplication,
                initialApplicationId: id,
                openAtCompletion:
                    current.kind == NotificationKind.lessonConfirmation,
              ),
        ),
      );
    } finally {
      _openingTarget = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: source ?? const AlwaysStoppedAnimation(0),
          builder: (context, _) {
            if (_loading) {
              return const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Bildirimler yükleniyor',
                ),
              );
            }
            final items = [
              for (final item
                  in source?.notifications ?? const <StudyNotification>[])
                if (item.recipientId == widget.user.id) item,
            ]..sort((a, b) {
              final byDate = b.createdAt.compareTo(a.createdAt);
              return byDate == 0 ? a.id.compareTo(b.id) : byDate;
            });
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (source != null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextButton(
                        onPressed:
                            _updating || source.unreadCount == 0
                                ? null
                                : () => _update(
                                  source.markAllRead,
                                  'Bildirimler okundu olarak işaretlenemedi. Tekrar deneyebilirsin.',
                                ),
                        child: const Text(
                          'Tümünü Okundu İşaretle',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                if (_updating)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Bildirimler güncelleniyor',
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    children: [
                      if (_loadFailed) ...[
                        const Text(
                          'Bildirimler yüklenemedi.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: _updating ? null : _load,
                          child: const Text('Tekrar Dene'),
                        ),
                      ] else if (widget.repository != null && source == null)
                        const Text(
                          'Bu hesabın bildirimleri görüntülenemiyor.',
                          textAlign: TextAlign.center,
                        )
                      else if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Henüz bildirimin yok.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _NotificationCard(
                            item: item,
                            onTap: _updating ? null : () => _open(item),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, this.onTap});
  final StudyNotification item;
  final VoidCallback? onTap;

  String get _date {
    final date = item.createdAt.toLocal();
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${pad(date.day)}.${pad(date.month)}.${date.year} • ${pad(date.hour)}:${pad(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final icon = switch (item.kind) {
      NotificationKind.newApplication => Icons.inbox_outlined,
      NotificationKind.applicationAccepted => Icons.check_circle_outline,
      NotificationKind.applicationRejected => Icons.cancel_outlined,
      NotificationKind.newMessage => Icons.chat_bubble_outline,
      NotificationKind.lessonConfirmation => Icons.task_alt,
    };
    return Semantics(
      key: ValueKey('notification-${item.id}'),
      label: item.isRead ? 'Okundu' : 'Okunmadı',
      child: ProfilePanel(
        backgroundColor: colors.onPrimary,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.primary,
                        fontWeight:
                            item.isRead ? FontWeight.w600 : FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(item.description),
                    const SizedBox(height: 8),
                    Text(
                      _date,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  key: ValueKey('notification-unread-${item.id}'),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
