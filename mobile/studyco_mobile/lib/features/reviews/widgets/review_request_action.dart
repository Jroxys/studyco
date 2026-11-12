import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../applications/models/application.dart';
import '../../profile/models/user_profile.dart';
import '../domain/reviews_repository.dart';
import 'reviews_repository_scope.dart';
import 'rating_stars.dart';

/// One entry point shared by both participant roles; authorization stays in the repository.
class ReviewRequestAction extends StatefulWidget {
  const ReviewRequestAction({
    super.key,
    required this.application,
    required this.user,
    required this.lessonTitle,
  });
  final Application application;
  final UserProfile user;
  final String lessonTitle;
  @override
  State<ReviewRequestAction> createState() => _ReviewRequestActionState();
}

class _ReviewRequestActionState extends State<ReviewRequestAction> {
  ReviewsRepository? _source;
  Future<ReviewEligibility>? _eligibility;
  String? _actorId;
  bool _opening = false;
  bool _saved = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final source = ReviewsRepositoryScope.maybeOf(context);
    if (!identical(source, _source) || _eligibility == null) {
      _source?.removeListener(_reload);
      _source = source;
      _source?.addListener(_reload);
      _configure();
    }
  }

  void _configure() {
    _actorId =
        _source?.isLocal == true ? widget.user.postsOwnerId : widget.user.id;
    _eligibility =
        !widget.application.isCompletedLesson ||
                _source == null ||
                _actorId == null
            ? null
            : _source!.eligibilityForRequest(
              widget.application.id,
              reviewerId: _actorId!,
            );
  }

  void _reload() {
    if (mounted) setState(_configure);
  }

  @override
  void didUpdateWidget(covariant ReviewRequestAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.application != widget.application ||
        oldWidget.user != widget.user) {
      _saved = false;
      _configure();
    }
  }

  @override
  void dispose() {
    _source?.removeListener(_reload);
    super.dispose();
  }

  Future<void> _open(ReviewEligibility eligibility) async {
    final source = _source;
    final actorId = _actorId;
    if (_opening || source == null || actorId == null) return;
    setState(() => _opening = true);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => ReviewFormSheet(
            repository: source,
            requestId: widget.application.id,
            reviewerId: actorId,
            eligibility: eligibility,
            lessonTitle: widget.lessonTitle,
          ),
    );
    if (!mounted) return;
    setState(() {
      _opening = false;
      _saved = saved == true;
      _configure();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.application.isCompletedLesson || _eligibility == null) {
      return const SizedBox.shrink();
    }
    return FutureBuilder<ReviewEligibility>(
      future: _eligibility,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Değerlendirme bilgisi yükleniyor…'),
          );
        }
        if (snapshot.hasError) {
          return TextButton(
            onPressed: _reload,
            child: const Text('Değerlendirme bilgisi alınamadı. Tekrar dene'),
          );
        }
        final eligibility = snapshot.data;
        if (eligibility?.alreadyReviewed == true) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _saved ? 'Değerlendirmen kaydedildi.' : 'Değerlendirdin',
              key: const ValueKey('reviewed-request'),
            ),
          );
        }
        if (eligibility?.canReview != true) return const SizedBox.shrink();
        return FilledButton.icon(
          onPressed: _opening ? null : () => _open(eligibility!),
          icon: const Icon(Icons.star_outline_rounded),
          label: const Text('Değerlendir'),
        );
      },
    );
  }
}

class ReviewFormSheet extends StatefulWidget {
  const ReviewFormSheet({
    super.key,
    required this.repository,
    required this.requestId,
    required this.reviewerId,
    required this.eligibility,
    required this.lessonTitle,
  });
  final ReviewsRepository repository;
  final String requestId;
  final String reviewerId;
  final ReviewEligibility eligibility;
  final String lessonTitle;
  @override
  State<ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<ReviewFormSheet> {
  final _form = GlobalKey<FormState>();
  final _comment = TextEditingController();
  int _rating = 0;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _rating == 0 || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.submitForRequest(
        requestId: widget.requestId,
        reviewerId: widget.reviewerId,
        revieweeId: widget.eligibility.revieweeId!,
        rating: _rating,
        comment: _comment.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Değerlendirme kaydedilemedi. Tekrar deneyebilirsin.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: FractionallySizedBox(
        heightFactor: .88,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Değerlendir',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.onPrimary,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.lessonTitle,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.eligibility.revieweeName ??
                                    'Katılımcı adı mevcut değil.',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Dersi nasıl buldun?'),
                        RatingStars(
                          rating: _rating.toDouble(),
                          size: 32,
                          enabled: !_busy,
                          onSelected:
                              (rating) => setState(() => _rating = rating),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _comment,
                          enabled: !_busy,
                          minLines: 3,
                          maxLines: 6,
                          maxLength: 1000,
                          maxLengthEnforcement: MaxLengthEnforcement.none,
                          decoration: const InputDecoration(
                            labelText: 'Yorumun (isteğe bağlı)',
                            alignLabelWithHint: true,
                          ),
                          validator:
                              (value) =>
                                  (value?.runes.length ?? 0) > 1000
                                      ? 'Yorum en fazla 1000 karakter olabilir.'
                                      : null,
                        ),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _error!,
                              style: TextStyle(color: colors.error),
                            ),
                          ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _busy || _rating == 0 ? null : _submit,
                          child: Text(_busy ? 'Gönderiliyor…' : 'Gönder'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
