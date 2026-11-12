import 'package:flutter/material.dart';
import '../domain/reviews_repository.dart';
import '../models/review.dart';
import '../widgets/rating_summary.dart';
import '../widgets/review_card.dart';

/// User-ID based received reviews, reusable independently of Profile navigation.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({
    super.key,
    required this.userId,
    required this.repository,
    this.ownReviews = true,
  });
  final String? userId;
  final ReviewsRepository? repository;
  final bool ownReviews;
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  List<Review> _items = [];
  ReviewStatistics? _overall;
  String? _cursor;
  final _seenCursors = <String>{};
  bool _loaded = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String? _moreError;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    widget.repository?.addListener(_reviewsChanged);
    _fetch();
  }

  @override
  void didUpdateWidget(covariant ReviewsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.repository != widget.repository) {
      oldWidget.repository?.removeListener(_reviewsChanged);
      widget.repository?.addListener(_reviewsChanged);
      _items = [];
      _overall = null;
      _cursor = null;
      _loaded = false;
      _seenCursors.clear();
      _fetch(force: true);
    }
  }

  void _reviewsChanged() => _fetch(force: true);

  @override
  void dispose() {
    widget.repository?.removeListener(_reviewsChanged);
    super.dispose();
  }

  Future<void> _fetch({bool more = false, bool force = false}) async {
    if (!force && (_loading || _loadingMore || (more && _cursor == null))) {
      return;
    }
    final generation = ++_generation;
    final requestedCursor = more ? _cursor : null;
    setState(() {
      if (more) {
        _loadingMore = true;
        _moreError = null;
      } else {
        _loading = true;
        _loadingMore = false;
        _error = null;
        _moreError = null;
      }
    });
    try {
      final repository = widget.repository;
      final userId = widget.userId;
      if (repository == null || userId == null || userId.trim().isEmpty) {
        throw const ReviewsFailure(
          'Değerlendirmeler şu anda görüntülenemiyor.',
        );
      }
      final page = await repository.fetchForUser(
        userId,
        cursor: requestedCursor,
      );
      if (!mounted || generation != _generation) return;
      if (more &&
          page.nextCursor != null &&
          _seenCursors.contains(page.nextCursor)) {
        throw const ReviewsFailure(
          'Diğer değerlendirmeler yüklenemedi. Listeyi yenileyip tekrar dene.',
        );
      }
      final merged = <String, Review>{
        if (more)
          for (final item in _items) item.id: item,
      };
      for (final item in page.items) {
        merged[item.id] = item;
      }
      _items = List.unmodifiable(merged.values);
      _overall = more ? page.overall ?? _overall : page.overall;
      if (!more) _seenCursors.clear();
      _cursor = page.nextCursor;
      if (_cursor != null) _seenCursors.add(_cursor!);
      _loaded = true;
    } catch (error) {
      if (!mounted || generation != _generation) return;
      final message =
          error is ReviewsFailure
              ? error.message
              : more
              ? 'Diğer değerlendirmeler yüklenemedi. Lütfen tekrar dene.'
              : 'Değerlendirmeler yüklenemedi. Lütfen tekrar dene.';
      if (more) {
        _moreError = message;
      } else {
        _error = message;
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Widget _empty({String? error}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.onPrimary,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.secondary.withValues(alpha: .12),
              ),
              child: Icon(
                error == null
                    ? Icons.rate_review_outlined
                    : Icons.wifi_off_rounded,
                color: colors.secondary,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              error == null
                  ? widget.ownReviews
                      ? 'İlk yorumun burada görünecek'
                      : 'İlk yorum burada görünecek'
                  : 'Bir sorun oluştu',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              error ??
                  (widget.ownReviews
                      ? 'Henüz sana değerlendirme yapılmadı. Aldığın puanlar ve yorumlar burada yer alacak.'
                      : 'Bu kullanıcıya henüz değerlendirme yapılmadı.'),
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.5, color: colors.onSurfaceVariant),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _loading ? null : () => _fetch(),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statistics =
        _loaded
            ? ReviewPage(
              items: _items,
              nextCursor: _cursor,
              overall: _overall,
            ).statistics
            : null;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.alphaBlend(
          colors.secondary.withValues(alpha: .06),
          colors.surface,
        ),
        title: Text(
          widget.ownReviews ? 'Değerlendirmelerim' : 'Değerlendirmeler',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading || _loadingMore ? null : () => _fetch(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: CustomScrollView(
              key: const ValueKey('reviews-scroll'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.ownReviews
                              ? 'Diğer öğrencilerin sana verdiği puanlar ve yorumlar.'
                              : 'Bu kullanıcıya verilen puanlar ve yorumlar.',
                          style: const TextStyle(height: 1.5),
                        ),
                        const SizedBox(height: 18),
                        RatingSummary(
                          title:
                              widget.ownReviews
                                  ? 'Genel Değerlendirme Puanım'
                                  : 'Genel Değerlendirme Puanı',
                          statistics: statistics,
                          loading: _loading,
                          unavailable: _error != null,
                          loadedCount: _items.length,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_error != null ||
                    (_loaded && _items.isEmpty && _cursor == null))
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverToBoxAdapter(child: _empty(error: _error)),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: _items.length,
                      itemBuilder:
                          (_, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: ReviewCard(
                              key: ValueKey('review-${_items[index].id}'),
                              review: _items[index],
                            ),
                          ),
                    ),
                  ),
                  if (_cursor != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_moreError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _moreError!,
                                  style: TextStyle(
                                    color: colors.error,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            OutlinedButton(
                              key: const ValueKey('reviews-load-more'),
                              onPressed:
                                  _loadingMore
                                      ? null
                                      : () => _fetch(more: true),
                              child: Text(
                                _loadingMore
                                    ? 'Yükleniyor…'
                                    : _moreError != null
                                    ? 'Tekrar Dene'
                                    : 'Daha Fazla Göster',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
