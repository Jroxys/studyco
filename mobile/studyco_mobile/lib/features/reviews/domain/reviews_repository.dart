import 'package:flutter/foundation.dart';
import '../models/review.dart';

class ReviewsFailure implements Exception {
  const ReviewsFailure(this.message);
  final String message;
}

class ReviewPage {
  ReviewPage({
    required Iterable<Review> items,
    required this.nextCursor,
    this.overall,
  }) : items = List.unmodifiable(items);
  final List<Review> items;
  final String? nextCursor;

  /// Optional trusted statistics for ALL received reviews. Domain metadata,
  /// not an assumed field of the current paginated backend response.
  final ReviewStatistics? overall;

  /// Shared reliability rule for full collections and trusted aggregate data.
  /// A partial page without an aggregate must never become an overall score.
  ReviewStatistics? get statistics =>
      overall ??
      (nextCursor == null ? ReviewStatistics.fromReviews(items) : null);
}

class ReviewEligibility {
  const ReviewEligibility({
    this.revieweeId,
    this.revieweeName,
    this.alreadyReviewed = false,
  });
  final String? revieweeId;
  final String? revieweeName;
  final bool alreadyReviewed;
  bool get canReview => revieweeId != null && !alreadyReviewed;
}

abstract class ReviewsRepository extends ChangeNotifier {
  bool get isLocal => false;
  Future<ReviewPage> fetchForUser(
    String userId, {
    int limit = 20,
    String? cursor,
  });

  /// Lightweight profile projection from the same source. Remote adapters may
  /// override only when a verified full-dataset statistics contract exists.
  Future<ReviewStatistics?> fetchSummaryForUser(String userId) async =>
      (await fetchForUser(userId)).statistics;
  Future<ReviewEligibility> eligibilityForRequest(
    String requestId, {
    required String reviewerId,
  }) async => const ReviewEligibility();
  Future<bool> hasReviewedRequest(
    String requestId, {
    required String reviewerId,
  }) async =>
      (await eligibilityForRequest(
        requestId,
        reviewerId: reviewerId,
      )).alreadyReviewed;
  Future<Review> submitForRequest({
    required String requestId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    String? comment,
  }) async {
    throw const ReviewsFailure(
      'Değerlendirme kaydedilemedi. Tekrar deneyebilirsin.',
    );
  }
}

void validateReviewQuery(String userId, int limit) {
  if (userId.trim().isEmpty) {
    throw const ReviewsFailure('Kullanıcı bilgisi doğrulanamadı.');
  }
  RangeError.checkValueInInterval(limit, 1, 50, 'limit');
}
