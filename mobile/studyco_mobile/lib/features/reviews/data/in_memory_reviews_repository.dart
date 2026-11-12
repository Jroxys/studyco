import '../../applications/domain/applications_repository.dart';
import '../domain/reviews_repository.dart';
import '../models/review.dart';

/// Received-review collections indexed explicitly by recipient ID.
/// No JWT, network, fabricated recipient objects or name-based lookups.
class InMemoryReviewsRepository extends ReviewsRepository {
  InMemoryReviewsRepository({
    Map<String, Iterable<Review>> initialByUser = const {},
    this.applicationsRepository,
    this.authenticatedUser,
  }) : _byUser = Map.of(
         initialByUser.map((id, reviews) {
           final items =
               reviews.toList()..sort((a, b) {
                 final date = b.createdAt.compareTo(a.createdAt);
                 return date == 0 ? a.id.compareTo(b.id) : date;
               });
           if (items.map((item) => item.id).toSet().length != items.length) {
             throw ArgumentError('Değerlendirme kimlikleri benzersiz olmalı.');
           }
           return MapEntry(id, List<Review>.unmodifiable(items));
         }),
       );
  final ApplicationsRepository? applicationsRepository;

  /// Trusted composition-root identity, never supplied by a form field.
  final ReviewReviewer? Function()? authenticatedUser;
  final Map<String, List<Review>> _byUser;
  final _cursors = <String, ({String userId, int offset})>{};
  int _sequence = 0;
  @override
  bool get isLocal => true;
  @override
  Future<ReviewPage> fetchForUser(
    String userId, {
    int limit = 20,
    String? cursor,
  }) async {
    validateReviewQuery(userId, limit);
    var offset = 0;
    if (cursor != null) {
      final ticket = _cursors[cursor];
      if (ticket == null || ticket.userId != userId) {
        throw const ReviewsFailure('Liste yenilenmeli. Lütfen tekrar dene.');
      }
      offset = ticket.offset;
    }
    final all = _byUser[userId] ?? const <Review>[];
    final end = (offset + limit).clamp(0, all.length);
    String? next;
    if (end < all.length) {
      next = 'local-review-cursor-${_sequence++}';
      _cursors[next] = (userId: userId, offset: end);
    }
    return ReviewPage(
      items: all.sublist(offset, end),
      nextCursor: next,
      overall: ReviewStatistics.fromReviews(all),
    );
  }

  ReviewReviewer _actor(String reviewerId) {
    final actor = authenticatedUser?.call();
    if (actor == null || actor.id.trim().isEmpty || actor.id != reviewerId) {
      throw const ReviewsFailure('Kullanıcı kimliği doğrulanamadı.');
    }
    return actor;
  }

  bool _hasReviewed(String requestId, String reviewerId) => _byUser.values
      .expand((items) => items)
      .any(
        (review) =>
            review.requestId == requestId && review.reviewer.id == reviewerId,
      );

  ReviewEligibility _eligibility(String requestId, String reviewerId) {
    _actor(reviewerId);
    final application = applicationsRepository?.getForUser(
      requestId,
      userId: reviewerId,
    );
    if (application == null || !application.isCompletedLesson) {
      return const ReviewEligibility();
    }
    final teacherId = application.teacherId;
    if (teacherId == null ||
        teacherId.trim().isEmpty ||
        application.applicantId.trim().isEmpty ||
        teacherId == application.applicantId) {
      return const ReviewEligibility();
    }
    final student = reviewerId == application.applicantId;
    if (!student && reviewerId != teacherId) return const ReviewEligibility();
    final person = student ? application.teacher : application.applicant;
    final target = student ? teacherId : application.applicantId;
    return ReviewEligibility(
      revieweeId: target,
      revieweeName: person?.id == target ? person?.displayName : null,
      alreadyReviewed: _hasReviewed(requestId, reviewerId),
    );
  }

  @override
  Future<ReviewEligibility> eligibilityForRequest(
    String requestId, {
    required String reviewerId,
  }) async => _eligibility(requestId, reviewerId);

  @override
  Future<bool> hasReviewedRequest(
    String requestId, {
    required String reviewerId,
  }) async {
    _actor(reviewerId);
    return _hasReviewed(requestId, reviewerId);
  }

  @override
  Future<Review> submitForRequest({
    required String requestId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    String? comment,
  }) async {
    // No await between authorization, uniqueness check and commit.
    final actor = _actor(reviewerId);
    final eligibility = _eligibility(requestId, reviewerId);
    if (!eligibility.canReview ||
        eligibility.revieweeId != revieweeId ||
        rating < 1 ||
        rating > 5 ||
        (comment?.runes.length ?? 0) > 1000) {
      throw const ReviewsFailure('Bu ders için değerlendirme yapılamıyor.');
    }
    final text = comment?.trim();
    final review = Review(
      id:
          'local-submitted-review-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      requestId: requestId,
      reviewer: actor,
      rating: rating,
      comment: text == null || text.isEmpty ? null : text,
      createdAt: DateTime.now().toUtc(),
    );
    _byUser[revieweeId] = List.unmodifiable([review, ...?_byUser[revieweeId]]);
    // Old offsets cannot safely paginate a changed collection.
    _cursors.removeWhere((_, ticket) => ticket.userId == revieweeId);
    notifyListeners();
    return review;
  }

  @override
  void dispose() {
    _cursors.clear();
    super.dispose();
  }
}
