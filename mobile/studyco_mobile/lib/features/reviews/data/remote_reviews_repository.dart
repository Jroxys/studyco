import '../../../core/api/api_client.dart';
import '../../applications/domain/applications_repository.dart';
import '../domain/reviews_repository.dart';
import '../models/review.dart';
import 'review_dto.dart';

/// `/api/v1/users/:id/reviews` and `/api/v1/requests/:id/reviews`.
class RemoteReviewsRepository extends ReviewsRepository {
  RemoteReviewsRepository({
    required this.api,
    required this.userId,
    required this.applicationsRepository,
  });

  final ApiClient api;
  final String userId;
  final ApplicationsRepository applicationsRepository;

  @override
  Future<ReviewPage> fetchForUser(
    String userId, {
    int limit = 20,
    String? cursor,
  }) async {
    validateReviewQuery(userId, limit);
    try {
      final json = await api.get(
        '/users/$userId/reviews',
        query: {'limit': limit, 'cursor': cursor},
      );
      return ReviewDto.pageFromJson(json as Map<String, dynamic>);
    } catch (error) {
      throw ReviewsFailure(
        apiErrorMessage(error, fallback: 'Değerlendirmeler yüklenemedi.'),
      );
    }
  }

  @override
  Future<ReviewEligibility> eligibilityForRequest(
    String requestId, {
    required String reviewerId,
  }) async {
    if (reviewerId != userId) return const ReviewEligibility();
    final application = applicationsRepository.getForUser(
      requestId,
      userId: reviewerId,
    );
    if (application == null || !application.isCompletedLesson) {
      return const ReviewEligibility();
    }
    final teacherId = application.teacherId;
    if (teacherId == null || teacherId == application.applicantId) {
      return const ReviewEligibility();
    }
    final student = reviewerId == application.applicantId;
    if (!student && reviewerId != teacherId) return const ReviewEligibility();
    final person = student ? application.teacher : application.applicant;
    return ReviewEligibility(
      revieweeId: student ? teacherId : application.applicantId,
      revieweeName: person?.displayName,
      alreadyReviewed: await hasReviewedRequest(
        requestId,
        reviewerId: reviewerId,
      ),
    );
  }

  @override
  Future<bool> hasReviewedRequest(
    String requestId, {
    required String reviewerId,
  }) async {
    try {
      final json = await api.get('/requests/$requestId/reviews');
      final items = json is Map<String, dynamic> ? json['items'] : json;
      if (items is! List) return false;
      return items.cast<Map<String, dynamic>>().any(
        (item) =>
            (item['reviewer'] as Map<String, dynamic>?)?['id'] == reviewerId,
      );
    } catch (error) {
      throw ReviewsFailure(
        apiErrorMessage(error, fallback: 'Değerlendirme durumu alınamadı.'),
      );
    }
  }

  @override
  Future<Review> submitForRequest({
    required String requestId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    String? comment,
  }) async {
    if (reviewerId != userId) {
      throw const ReviewsFailure('Kullanıcı kimliği doğrulanamadı.');
    }
    final text = comment?.trim();
    try {
      final json = await api.post(
        '/requests/$requestId/reviews',
        body: {
          'rating': rating,
          if (text != null && text.isNotEmpty) 'comment': text,
        },
      );
      final review = ReviewDto.fromJson(json as Map<String, dynamic>);
      notifyListeners();
      return review;
    } catch (error) {
      throw ReviewsFailure(
        apiErrorMessage(
          error,
          fallback: 'Değerlendirme kaydedilemedi. Tekrar deneyebilirsin.',
        ),
      );
    }
  }
}
