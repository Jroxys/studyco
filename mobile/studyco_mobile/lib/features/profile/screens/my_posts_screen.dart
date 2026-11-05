import 'dart:async';
import 'package:flutter/material.dart';
import '../../posts/domain/posts_repository.dart';
import '../../posts/models/post.dart';
import '../../posts/screens/create_post_screen.dart';
import '../../posts/screens/post_details_screen.dart';
import '../models/user_profile.dart';

class MyPostsScreen extends StatefulWidget {
  const MyPostsScreen({
    super.key,
    required this.repository,
    required this.user,
  });
  final PostsRepository repository;
  final UserProfile user;
  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen> {
  final _deleting = <String>{};
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _delete(Post post) async {
    if (_deleting.contains(post.id)) return;
    if (!_canManage(post)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('İlanı Sil'),
            content: const Text('Bu ilanı silmek istediğine emin misin?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgeç'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('İlanı Sil'),
              ),
            ],
          ),
    );
    if (!mounted || confirmed != true || _deleting.contains(post.id)) return;
    if (!_canManage(post)) return;
    setState(() => _deleting.add(post.id));
    try {
      await widget.repository.deletePost(
        post.id,
        ownerId: widget.user.postsOwnerId,
      );
      if (mounted) _message('İlan silindi.');
    } catch (_) {
      if (mounted) _message('İlan silinemedi. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _deleting.remove(post.id));
    }
  }

  bool _canManage(Post post) {
    try {
      widget.repository.requireMutablePost(
        post.id,
        ownerId: widget.user.postsOwnerId,
      );
      return true;
    } on StateError {
      _message(
        'İlan artık yönetilemiyor. Geçmiş ilanlar yalnızca görüntülenebilir.',
      );
      return false;
    }
  }

  Future<void> _edit(Post post) async {
    if (!_canManage(post)) return;
    if (!widget.repository.supportsFullPostEditing) {
      _message('Bu veri kaynağı henüz ilan düzenlemeyi desteklemiyor.');
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => CreatePostScreen(
              repository: widget.repository,
              user: widget.user,
              initialPost: post,
            ),
      ),
    );
    if (mounted && saved == true) _message('İlan güncellendi.');
  }

  Widget _card(Post post, DateTime now) {
    final colors = Theme.of(context).colorScheme;
    final busy = _deleting.contains(post.id);
    String time(DateTime date) =>
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final ended = post.isExpiredAt(now);
    return Container(
      key: ValueKey('my-post-${post.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.onPrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(post.typeLabel),
                backgroundColor: colors.secondary.withValues(alpha: .12),
              ),
              Chip(
                label: Text(
                  ended
                      ? 'Süresi Doldu'
                      : post.status == PostStatus.booked
                      ? 'Rezerve Edildi'
                      : post.status == PostStatus.published
                      ? 'Aktif'
                      : 'Kapalı',
                ),
              ),
            ],
          ),
          TextButton(
            onPressed:
                busy
                    ? null
                    : () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder:
                            (_) => PostDetailsScreen(
                              post: post,
                              repository: widget.repository,
                              user: widget.user,
                            ),
                      ),
                    ),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
            ),
            child: Text(
              post.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            'Konu: ${post.topic?.trim().isNotEmpty == true ? post.topic : 'Belirtilmemiş'}',
          ),
          const SizedBox(height: 10),
          Text(
            '${post.startsAt.day}/${post.startsAt.month}/${post.startsAt.year} • ${time(post.startsAt)} – ${time(post.endsAt)}',
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 20,
                color: colors.secondary,
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(post.location)),
            ],
          ),
          const SizedBox(height: 8),
          Text(post.offerLabel),
          if (post.applicationCount != null) ...[
            const SizedBox(height: 8),
            Text('Gelen başvuru: ${post.applicationCount}'),
          ],
          if (!ended && post.status == PostStatus.published) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _edit(post),
                    child: const Text(
                      'İlanı Düzenle',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _delete(post),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.error,
                    ),
                    child: Text(
                      busy ? 'Siliniyor…' : 'İlanı Sil',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(title: const Text('İlanlarım')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Text('Oluşturduğun ilanları görüntüle ve yönet.'),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Aktif İlanlar'),
                    Tab(text: 'Geçmiş İlanlar'),
                  ],
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: widget.repository,
                    builder: (context, _) {
                      final now = DateTime.now();
                      final owned =
                          widget.repository.posts
                              .where(
                                (post) =>
                                    post.authorId == widget.user.postsOwnerId,
                              )
                              .toList()
                            ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
                      return TabBarView(
                        children: [
                          for (final past in [false, true])
                            Builder(
                              builder: (_) {
                                final posts =
                                    owned
                                        .where(
                                          (post) =>
                                              post.isExpiredAt(now) == past,
                                        )
                                        .toList();
                                if (posts.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        past
                                            ? 'Henüz geçmiş ilanın yok.'
                                            : 'Henüz aktif ilanın yok.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                }
                                return ListView.builder(
                                  key: PageStorageKey('my-posts-$past'),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: posts.length,
                                  itemBuilder:
                                      (_, index) => _card(posts[index], now),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
