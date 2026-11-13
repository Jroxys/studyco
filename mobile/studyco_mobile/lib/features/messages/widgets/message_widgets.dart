import 'package:flutter/material.dart';
import '../../profile/widgets/profile_widgets.dart';
import '../models/conversation.dart';

String messageTime(DateTime time, {bool date = false}) {
  final local = time.toLocal();
  final clock =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return date ? '${local.day}.${local.month}.${local.year} $clock' : clock;
}

class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({super.key, required this.conversation});
  final Conversation conversation;
  @override
  Widget build(BuildContext context) {
    final person = conversation.counterpart;
    final initials =
        [person.firstName, person.lastNameInitial]
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .map((s) => s.trim().characters.first)
            .join()
            .toUpperCase();
    final colors = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: colors.secondary.withValues(alpha: .16),
      foregroundColor: colors.primary,
      child: Text(initials),
    );
  }
}

class ConversationCard extends StatelessWidget {
  const ConversationCard({
    super.key,
    required this.conversation,
    required this.onTap,
  });
  final Conversation conversation;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = conversation;
    return ProfilePanel(
      backgroundColor:
          c.unreadCount > 0
              ? Color.alphaBlend(
                Theme.of(context).colorScheme.secondary.withValues(alpha: .08),
                Colors.white,
              )
              : Colors.white,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ConversationAvatar(conversation: c),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.counterpart.displayName ?? 'Kullanıcı',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(c.topic, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(
                    c.lastMessage?.body ?? 'Henüz mesaj yok',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (c.lastMessage != null)
                    Text(
                      messageTime(c.lastMessage!.sentAt, date: true),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (c.unreadCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Semantics(
                  label: '${c.unreadCount} okunmamış mesaj',
                  child: Badge(label: Text('${c.unreadCount}')),
                ),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.isOwn});
  final Message message;
  final bool isOwn;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: .86,
        child: Align(
          alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isOwn ? colors.primary : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.body,
                  style: TextStyle(
                    color: isOwn ? colors.onPrimary : colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  messageTime(message.sentAt, date: true),
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        isOwn
                            ? colors.onPrimary.withValues(alpha: .8)
                            : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
