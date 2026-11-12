import 'package:flutter/material.dart';
import '../../posts/models/post.dart';

class SearchPostCard extends StatelessWidget {
  const SearchPostCard({super.key, required this.post, required this.onOpen});
  final Post post;
  final VoidCallback onOpen;

  Widget _detail(BuildContext context, IconData icon, String label) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(
          icon,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final names =
        post.authorName
            .trim()
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .toList();
    final initials =
        names.take(2).map((name) => name.characters.first).join().toUpperCase();
    final topic = post.topic?.trim() ?? '';
    final showTopic = topic.isNotEmpty && topic != post.title.trim();
    return Card(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.primary.withValues(alpha: .10)),
      ),
      child: InkWell(
        key: ValueKey('search-post-${post.id}'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.secondary.withValues(alpha: .17),
                    foregroundColor: colors.primary,
                    child:
                        initials.isEmpty
                            ? const Icon(Icons.person_outline, size: 19)
                            : Text(
                              initials,
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (post.department?.trim().isNotEmpty ?? false)
                          Text(
                            post.department!,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48, height: 48),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                post.title,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 17,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showTopic)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.secondary.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      topic,
                      softWrap: true,
                      style: TextStyle(
                        color: colors.primary,
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              if (post.description?.trim().isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    post.description!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(
                  height: 1,
                  color: colors.outlineVariant.withValues(alpha: .65),
                ),
              ),
              _detail(
                context,
                Icons.schedule_rounded,
                '${post.dateLabel} – ${post.endsAt.hour.toString().padLeft(2, '0')}:${post.endsAt.minute.toString().padLeft(2, '0')}',
              ),
              const SizedBox(height: 7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _detail(
                      context,
                      Icons.location_on_outlined,
                      post.location,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _detail(
                      context,
                      Icons.local_cafe_outlined,
                      post.offerLabel,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
