import '../../../app/routing/assistant_navigation.dart';
import '../../assistant/data/in_memory_assistant_repository.dart';
import '../../assistant/models/assistant_content.dart';
import '../../assistant/widgets/assistant_repository_scope.dart';
import '../../assistant/widgets/assistant_sheet.dart';
import '../../messages/screens/conversations_screen.dart';
import '../../messages/widgets/messages_repository_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../posts/domain/posts_repository.dart';
import '../../posts/models/post.dart';
import '../../posts/widgets/post_card.dart';
import '../../search/screens/search_screen.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/widgets/profile_repository_scope.dart';
import '../../profile/navigation/profile_navigation.dart';
import '../widgets/home_bottom_navigation.dart';
import '../widgets/home_header.dart';
import '../../notifications/domain/notifications_repository.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../notifications/widgets/notifications_repository_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.user,
    this.onOpenPost,
    this.onDestination,
    this.onCreatePost,
    this.isPreview = false,
    this.previewActions,
  });
  final PostsRepository repository;
  final UserProfile user;
  final ValueChanged<Post>? onOpenPost;
  final ValueChanged<String>? onDestination;
  final Future<bool?> Function()? onCreatePost;
  final bool isPreview;
  final Widget? previewActions;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile get _user =>
      ProfileRepositoryScope.currentOf(context, widget.user);

  bool _loading = true;
  String? _error;
  int _loadRequest = 0;
  bool _assistantOpen = false;
  NotificationsRepository? _notifications;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configureNotifications();
  }

  void _configureNotifications() {
    final source = NotificationsRepositoryScope.forUser(
      context,
      widget.user.id,
    );
    if (identical(source, _notifications)) return;
    _notifications = source;
    if (source != null) _loadUnreadCount(source);
  }

  Future<void> _loadUnreadCount(NotificationsRepository source) async {
    // Defer notifier changes until the current build finishes.
    await Future<void>.value();
    if (!mounted || !identical(source, _notifications)) return;
    try {
      await source.refresh();
    } catch (_) {
      // Keep the last confirmed badge. The list exposes an explicit retry.
    }
  }

  void _openNotifications() {
    final user = _user;
    final source = _notifications;
    final posts = widget.repository;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => NotificationsScreen(
              user: user,
              repository: source,
              postsRepository: posts,
            ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) _load();
    if (oldWidget.user.id != widget.user.id) _configureNotifications();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final request = ++_loadRequest;
    final repository = widget.repository;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await repository.refresh();
    } catch (_) {
      if (mounted && request == _loadRequest) {
        setState(() => _error = 'İlanlar yüklenemedi. Tekrar deneyin.');
      }
    } finally {
      if (mounted && request == _loadRequest) {
        setState(() => _loading = false);
      }
    }
  }

  void _message(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openCreatePost() async {
    final published = await widget.onCreatePost!();
    if (mounted && published == true) {
      _message(
        'İlan bu oturumda eklendi. Sunucuya kalıcı olarak yayınlanmadı.',
      );
    }
  }

  Map<AssistantDestination, VoidCallback> _assistantActions() =>
      AssistantNavigation.actions(
        context,
        user: _user,
        posts: widget.repository,
        onHome: () {},
        onSearch: () => _destination('Ara'),
        onProfile: () => _destination('Profilim'),
        onCreatePost:
            widget.onCreatePost == null
                ? null
                : () => _destination('İlan Oluştur'),
      );

  Future<void> _openAssistant() async {
    if (_assistantOpen) return;
    final userId = _user.id;
    final source =
        AssistantRepositoryScope.maybeOf(context) ??
        InMemoryAssistantRepository.preview;
    final available = _assistantActions().keys.toSet();
    setState(() => _assistantOpen = true);
    try {
      final destination = await showAssistantSheet(
        context,
        repository: source,
        availableDestinations: available,
      );
      if (!mounted || destination == null) return;
      if (_user.id != userId) {
        _message('Hesap değişti. Asistanı yeniden açabilirsin.');
        return;
      }
      // Resolve again after dismissal in case a session source was removed.
      final action = _assistantActions()[destination];
      if (action == null) {
        _message('Bu yönlendirme şu anda kullanılamıyor.');
      } else {
        action();
      }
    } finally {
      if (mounted) setState(() => _assistantOpen = false);
    }
  }

  void _destination(String name) {
    if (name == 'Profilim' && widget.onDestination == null) {
      ProfileNavigation.open(
        context,
        user: _user,
        repository: widget.repository,
        sourceIndex: 0,
        onHome: () {},
      );
      return;
    }
    if (name == 'Ara' && widget.onDestination == null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder:
              (_) => SearchScreen(repository: widget.repository, user: _user),
        ),
      );
      return;
    }
    if (name == 'İlan Oluştur' && widget.onCreatePost != null) {
      _openCreatePost();
      return;
    }
    if (widget.onDestination != null) {
      widget.onDestination!(name);
      return;
    }
    _message('$name ekranı henüz kullanıma açık değil.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = Color.alphaBlend(
      colors.primary.withValues(alpha: 0.45),
      colors.secondary,
    );
    final headerColor = Color.alphaBlend(
      colors.secondary.withValues(alpha: 0.06),
      colors.surface,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: headerColor,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemStatusBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: headerColor,
        body: SafeArea(
          bottom: false,
          child: ColoredBox(
            color: colors.surface,
            child: AnimatedBuilder(
              animation: widget.repository,
              builder: (context, _) {
                final matchingPosts = widget.repository.discoverablePosts
                  .where((post) => post.type == PostType.tutoring)
                  .toList(growable: false)..sort((a, b) {
                  final byCreatedAt = b.createdAt.compareTo(a.createdAt);
                  return byCreatedAt != 0 ? byCreatedAt : a.id.compareTo(b.id);
                });
                final posts = matchingPosts.take(6).toList(growable: false);
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: HomeHeader(
                        user: _user,
                        isPreview: widget.isPreview,
                        onMessages: () {
                          final source = MessagesRepositoryScope.forUser(
                            context,
                            _user.id,
                          );
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder:
                                  (_) => ConversationsScreen(
                                    repository: source,
                                    userId: _user.id,
                                  ),
                            ),
                          );
                        },
                        unreadMessages:
                            MessagesRepositoryScope.forUser(
                              context,
                              _user.id,
                            )?.confirmedUnreadTotal,
                        unreadNotifications: _notifications?.unreadCount ?? 0,
                        onNotifications: _openNotifications,
                        onProfile: () => _destination('Profilim'),
                      ),
                    ),
                    if (widget.isPreview && widget.previewActions != null)
                      SliverToBoxAdapter(child: widget.previewActions),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Senin İçin Öneriler',
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'En yeni özel ders ilanları',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              key: const ValueKey('all-posts'),
                              onPressed: () => _destination('Ara'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Tümü', style: TextStyle(color: accent)),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: accent,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_loading)
                      const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    else if (_error != null)
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Text(_error!),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Tekrar Dene'),
                            ),
                          ],
                        ),
                      )
                    else if (posts.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Henüz ilan yok.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final textScale = MediaQuery.textScalerOf(
                              context,
                            ).scale(1).clamp(1.0, 4.0);
                            final cardWidth =
                                (constraints.crossAxisExtent - 14) / 2;
                            var cardHeight =
                                (constraints.crossAxisExtent < 330
                                    ? 276.0
                                    : 252.0) +
                                (textScale - 1) * 200;
                            for (final post in posts) {
                              final requiredHeight = PostCard.requiredHeight(
                                context,
                                post,
                                cardWidth,
                              );
                              if (requiredHeight > cardHeight) {
                                cardHeight = requiredHeight;
                              }
                            }
                            return SliverGrid.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    mainAxisExtent: cardHeight,
                                  ),
                              itemCount: posts.length,
                              itemBuilder: (context, index) {
                                final post = posts[index];
                                return PostCard(
                                  post: post,
                                  onOpen: () {
                                    if (widget.onOpenPost != null) {
                                      widget.onOpenPost!(post);
                                    } else {
                                      _destination('İlan Detay');
                                    }
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const ValueKey('home-ai'),
                  onPressed: _assistantOpen ? null : _openAssistant,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: const Size(128, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  icon: Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: colors.secondary,
                  ),
                  label: const Text('AI Asistan'),
                ),
              ),
            ),
            HomeBottomNavigation(
              onSelected: (index) {
                if (index == 0) {
                  return;
                }
                _destination(
                  const ['Ana Sayfa', 'İlan Oluştur', 'Ara', 'Profilim'][index],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
