import 'package:flutter/material.dart';
import '../../home/widgets/home_bottom_navigation.dart';
import '../models/profile_destination.dart';
import '../../posts/domain/posts_repository.dart';
import 'my_posts_screen.dart';
import '../../applications/screens/applications_screen.dart';
import '../../search/screens/search_screen.dart';
import '../models/user_profile.dart';
import '../widgets/profile_widgets.dart';
import '../widgets/profile_repository_scope.dart';
import 'edit_profile_screen.dart';
import '../../auth/widgets/session_logout_scope.dart';
import '../../settings/screens/settings_screen.dart';
import '../../reviews/domain/reviews_repository.dart';
import '../../reviews/models/review.dart';
import '../../reviews/widgets/reviews_repository_scope.dart';
import '../../reviews/screens/reviews_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.onDestination,
    this.onOpenSection,
    this.repository,
    this.reviewsRepository,
  });
  final UserProfile user;
  final PostsRepository? repository;
  final ReviewsRepository? reviewsRepository;
  final ValueChanged<int> onDestination;
  final ValueChanged<ProfileDestination>? onOpenSection;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile get user =>
      ProfileRepositoryScope.currentOf(context, widget.user);
  PostsRepository? get repository => widget.repository;
  ValueChanged<int> get onDestination => widget.onDestination;
  ValueChanged<ProfileDestination>? get onOpenSection => widget.onOpenSection;
  ReviewsRepository? _reviewsSource;
  String? _reviewUserId;
  ReviewStatistics? _rating;
  bool _ratingLoading = false;
  bool _ratingError = false;
  bool _ratingConfigured = false;
  int _ratingGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configureRating();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configureRating();
  }

  void _configureRating() {
    final source =
        widget.reviewsRepository ?? ReviewsRepositoryScope.maybeOf(context);
    final userId = source?.isLocal == true ? user.postsOwnerId : user.id;
    if (_ratingConfigured &&
        identical(source, _reviewsSource) &&
        userId == _reviewUserId) {
      return;
    }
    _ratingConfigured = true;
    _reviewsSource?.removeListener(_loadRating);
    _reviewsSource = source;
    _reviewsSource?.addListener(_loadRating);
    _reviewUserId = userId;
    _rating = null;
    _loadRating();
  }

  Future<void> _loadRating() async {
    final generation = ++_ratingGeneration;
    final source = _reviewsSource;
    final userId = _reviewUserId;
    setState(() {
      _ratingLoading = true;
      _ratingError = false;
      _rating = null;
    });
    try {
      if (source == null || userId == null || userId.trim().isEmpty) {
        throw const ReviewsFailure('Puan bilgisi alınamadı.');
      }
      final summary = await source.fetchSummaryForUser(userId);
      if (!mounted || generation != _ratingGeneration) return;
      _rating = summary;
    } catch (_) {
      if (!mounted || generation != _ratingGeneration) return;
      _ratingError = true;
    } finally {
      if (mounted && generation == _ratingGeneration) {
        setState(() => _ratingLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _reviewsSource?.removeListener(_loadRating);
    super.dispose();
  }

  String get _ratingCaption {
    if (_ratingLoading) return 'Puan yükleniyor…';
    if (_ratingError) return 'Puan bilgisi alınamadı.';
    if (_rating == null) return 'Genel puan bekleniyor.';
    if (_rating!.count == 0) return 'Henüz değerlendirme yok';
    return 'Değerlendirme sayısı: ${_rating!.count}';
  }

  void _open(BuildContext context, ProfileDestination destination) {
    if (onOpenSection == null) {
      if (destination == ProfileDestination.settings) {
        final current = user;
        Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => SettingsScreen(user: current)),
        );
        return;
      }
      if (destination == ProfileDestination.logout) {
        SessionLogoutScope.confirm(
          context,
          endSession: SessionLogoutScope.forUser(context, user.id),
        );
        return;
      }
    }
    if (destination == ProfileDestination.edit && onOpenSection == null) {
      final source = ProfileRepositoryScope.forUser(context, widget.user);
      Navigator.of(context)
          .push<bool>(
            MaterialPageRoute(
              builder:
                  (_) => EditProfileScreen(userId: user.id, repository: source),
            ),
          )
          .then((saved) {
            if (mounted && saved == true) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Profil bilgilerin güncellendi.')),
              );
            }
          });
      return;
    }
    if (destination == ProfileDestination.posts && repository != null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => MyPostsScreen(repository: repository!, user: user),
        ),
      );
      return;
    }
    if ((destination == ProfileDestination.applications ||
            destination == ProfileDestination.incomingApplications) &&
        repository != null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder:
              (_) => ApplicationsScreen(
                incoming:
                    destination == ProfileDestination.incomingApplications,
                postsRepository: repository!,
                repository: repository!.applicationsRepository,
                user: user,
                onBrowse:
                    destination == ProfileDestination.incomingApplications
                        ? null
                        : () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder:
                                (_) => SearchScreen(
                                  repository: repository!,
                                  user: user,
                                  onHome: () {
                                    final navigator = Navigator.of(context);
                                    navigator.pop();
                                    navigator.pop();
                                    onDestination(0);
                                  },
                                ),
                          ),
                        ),
              ),
        ),
      );
      return;
    }
    if (destination == ProfileDestination.reviews) {
      Navigator.of(context)
          .push<void>(
            MaterialPageRoute(
              builder:
                  (_) => ReviewsScreen(
                    userId: _reviewUserId,
                    repository: _reviewsSource,
                  ),
            ),
          )
          .then((_) {
            if (mounted) _loadRating();
          });
      return;
    }
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
                      value: _rating?.average?.toStringAsFixed(1) ?? '—',
                      caption: _ratingCaption,
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
