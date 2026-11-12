import '../../features/reviews/models/review.dart';
import 'home_preview_data.dart';

/// Explicit debug fixtures, not server records or generated completion events.
Map<String, List<Review>> previewReceivedReviews() {
  final now = DateTime.now().toUtc();
  return {
    sampleHomeUser.postsOwnerId: [
      Review(
        id: 'mock-review-1',
        requestId: 'mock-reviewed-request-1',
        reviewer: const ReviewReviewer(
          id: 'mock-reviewer-1',
          firstName: 'Ece (örnek)',
          lastNameInitial: 'K',
        ),
        rating: 5,
        comment:
            'Konuyu anlaşılır örneklerle anlattı. Birlikte çalışmak faydalıydı.',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      Review(
        id: 'mock-review-2',
        requestId: 'mock-reviewed-request-2',
        reviewer: const ReviewReviewer(
          id: 'mock-reviewer-2',
          firstName: 'Can (örnek)',
          lastNameInitial: 'D',
        ),
        rating: 4,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      Review(
        id: 'mock-review-3',
        requestId: 'mock-reviewed-request-3',
        reviewer: const ReviewReviewer(
          id: 'mock-reviewer-3',
          firstName: 'Aslı (örnek)',
          lastNameInitial: 'Y',
        ),
        rating: 5,
        comment: 'Sorularıma sabırla yanıt verdi.',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    ],
    previewTeacherId: [
      Review(
        id: 'mock-teacher-review-1',
        requestId: 'mock-teacher-request-1',
        reviewer: const ReviewReviewer(
          id: 'mock-teacher-reviewer-1',
          firstName: 'Mert (örnek)',
          lastNameInitial: 'A',
        ),
        rating: 4,
        comment: 'Örnekler konuyu anlamamı kolaylaştırdı.',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'mock-teacher-review-2',
        requestId: 'mock-teacher-request-2',
        reviewer: const ReviewReviewer(
          id: 'mock-teacher-reviewer-2',
          firstName: 'Selin (örnek)',
          lastNameInitial: 'B',
        ),
        rating: 5,
        comment: 'Sorularımı anlaşılır biçimde yanıtladı.',
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      Review(
        id: 'mock-teacher-review-3',
        requestId: 'mock-teacher-request-3',
        reviewer: const ReviewReviewer(
          id: 'mock-teacher-reviewer-3',
          firstName: 'Arda (örnek)',
          lastNameInitial: 'C',
        ),
        rating: 4,
        createdAt: now.subtract(const Duration(days: 6)),
      ),
    ],
  };
}
