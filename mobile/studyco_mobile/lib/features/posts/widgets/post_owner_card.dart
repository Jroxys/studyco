import 'package:flutter/material.dart';
import '../models/post.dart';
import '../../reviews/domain/reviews_repository.dart';
import '../../reviews/models/review.dart';
import '../../reviews/screens/reviews_screen.dart';
import '../../reviews/widgets/reviews_repository_scope.dart';

/// Compact author identity and trusted review projection, using the app source.
class PostOwnerCard extends StatefulWidget {
  const PostOwnerCard({
    super.key,
    required this.post,
    this.viewerId,
    this.reviewsRepository,
  });
  final Post post;
  final String? viewerId;
  final ReviewsRepository? reviewsRepository;
  @override
  State<PostOwnerCard> createState() => _PostOwnerCardState();
}

class _PostOwnerCardState extends State<PostOwnerCard> {
  ReviewsRepository? _source;
  String? _authorId;
  ReviewStatistics? _statistics;
  bool _configured = false;
  bool _loading = false;
  bool _error = false;
  bool _opening = false;
  int _generation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configure();
  }

  @override
  void didUpdateWidget(covariant PostOwnerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configure();
  }

  void _configure() {
    final source =
        widget.reviewsRepository ?? ReviewsRepositoryScope.maybeOf(context);
    final id = widget.post.authorId;
    if (_configured && identical(source, _source) && id == _authorId) return;
    _configured = true;
    _source?.removeListener(_load);
    _source = source;
    _source?.addListener(_load);
    _authorId = id;
    _load();
  }

  @override
  void dispose() {
    _source?.removeListener(_load);
    super.dispose();
  }

  bool get _hasIdentity => _authorId?.trim().isNotEmpty == true;
  Future<void> _load() async {
    final generation = ++_generation;
    final source = _source;
    final id = _authorId;
    setState(() {
      _statistics = null;
      _error = false;
      _loading = _hasIdentity && source != null;
    });
    if (!_hasIdentity || source == null) return;
    try {
      final summary = await source.fetchSummaryForUser(id!);
      if (!mounted || generation != _generation) return;
      _statistics = summary;
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _error = true;
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openReviews() async {
    final id = _authorId;
    final source = _source;
    if (!_hasIdentity || source == null || _opening) return;
    setState(() => _opening = true);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => ReviewsScreen(
              userId: id,
              repository: source,
              ownReviews: widget.viewerId != null && widget.viewerId == id,
            ),
      ),
    );
    if (!mounted) return;
    setState(() => _opening = false);
    _load();
  }

  String get _message {
    if (!_hasIdentity) return 'İlan sahibi kimliği mevcut değil.';
    if (_loading) return 'Puan bilgisi yükleniyor…';
    if (_error || _statistics == null) {
      return 'Puan bilgisi şu anda gösterilemiyor.';
    }
    return 'Henüz değerlendirme yok';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final stats = _statistics;
    final canOpen = _hasIdentity && _source != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canOpen && !_opening ? _openReviews : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: colors.secondary.withValues(alpha: .12),
                  child: Icon(Icons.person_outline, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.authorName.trim().isEmpty
                            ? 'İsim bilgisi mevcut değil.'
                            : widget.post.authorName,
                        key: const ValueKey('detail-author'),
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'İlan Sahibi',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.primary.withValues(alpha: .85),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!_loading &&
                          !_error &&
                          stats != null &&
                          stats.count > 0)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 18,
                              applyTextScaling: false,
                              color: colors.secondary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '${stats.average!.toStringAsFixed(1)} · ${stats.count} değerlendirme',
                                key: const ValueKey('owner-rating'),
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _message,
                                key: const ValueKey('owner-rating-message'),
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (_error && _hasIdentity && _source != null)
                              IconButton(
                                key: const ValueKey('owner-rating-retry'),
                                tooltip: 'Puanı yenile',
                                onPressed: _loading ? null : _load,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                icon: Icon(
                                  Icons.refresh,
                                  size: 20,
                                  color: colors.secondary,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (canOpen) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: colors.secondary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
