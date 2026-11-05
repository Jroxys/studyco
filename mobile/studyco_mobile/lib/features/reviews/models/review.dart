class ReviewReviewer {
  const ReviewReviewer({
    required this.id,
    this.firstName,
    this.lastNameInitial,
    this.departmentId,
  });
  final String id;
  final String? firstName;
  final String? lastNameInitial;
  final String? departmentId;
  String get displayName {
    final first = firstName?.trim();
    if (first == null || first.isEmpty) return 'Kullanıcı bilgisi mevcut değil';
    final initial = lastNameInitial?.trim();
    return initial == null || initial.isEmpty
        ? first
        : '$first ${initial.replaceAll('.', '')}.';
  }
}

/// Only fields provided by the review API. The recipient is query context,
/// not a fabricated reviewee field, and no lesson title is inferred.
class Review {
  Review({
    required this.id,
    required this.requestId,
    required this.reviewer,
    required int rating,
    this.comment,
    required this.createdAt,
  }) : rating = RangeError.checkValueInInterval(rating, 1, 5, 'rating');
  final String id;
  final String requestId;
  final ReviewReviewer reviewer;
  final int rating;
  final String? comment;
  final DateTime createdAt;
}

class ReviewStatistics {
  const ReviewStatistics._(this.count, this.totalRating);
  factory ReviewStatistics.fromReviews(Iterable<Review> reviews) {
    final byId = {for (final review in reviews) review.id: review};
    return ReviewStatistics._(
      byId.length,
      byId.values.fold(0, (sum, review) => sum + review.rating),
    );
  }
  final int count;
  final int totalRating;
  double? get average => count == 0 ? null : totalRating / count;
}
