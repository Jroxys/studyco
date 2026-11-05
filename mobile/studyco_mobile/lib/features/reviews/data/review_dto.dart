import '../domain/reviews_repository.dart';
import '../models/review.dart';

/// Mapper for the supplied JWT-protected API response. No HTTP code, lesson
/// lookup or assumed reviewee object. UUID strings are preserved unchanged.
abstract final class ReviewDto {
  static Review fromJson(Map<String, dynamic> json) {
    final person = json['reviewer'];
    if (person is! Map<String, dynamic>) {
      throw const FormatException('reviewer gerekli.');
    }
    final rating = json['rating'];
    if (rating is! int || rating < 1 || rating > 5) {
      throw const FormatException('rating 1–5 arasında tam sayı olmalı.');
    }
    final createdAt = DateTime.tryParse(_required(json, 'createdAt'));
    if (createdAt == null) throw const FormatException('createdAt geçersiz.');
    return Review(
      id: _required(json, 'id'),
      requestId: _required(json, 'requestId'),
      reviewer: ReviewReviewer(
        id: _required(person, 'id'),
        firstName: _string(person, 'firstName'),
        lastNameInitial: _string(person, 'lastNameInitial'),
        departmentId: _string(person, 'departmentId'),
      ),
      rating: rating,
      comment: _string(json, 'comment'),
      createdAt: createdAt,
    );
  }

  static ReviewPage pageFromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List || !json.containsKey('nextCursor')) {
      throw const FormatException('items ve nextCursor gerekli.');
    }
    final cursor = _string(json, 'nextCursor');
    if (cursor != null && cursor.trim().isEmpty) {
      throw const FormatException('nextCursor boş olamaz.');
    }
    return ReviewPage(
      items: items.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Değerlendirme kaydı geçersiz.');
        }
        return fromJson(item);
      }),
      nextCursor: cursor,
    );
  }

  static String? _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('$key metin olmalı.');
    return value;
  }

  static String _required(Map<String, dynamic> json, String key) {
    final value = _string(json, key);
    if (value == null || value.trim().isEmpty) {
      throw FormatException('$key gerekli.');
    }
    return value;
  }
}
