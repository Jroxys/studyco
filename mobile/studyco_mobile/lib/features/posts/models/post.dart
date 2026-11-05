enum PostType { tutoring }

/// Known backend values only: PUBLISHED and BOOKED. Unknown values stay closed.
enum PostStatus { published, booked, unknown }

enum PostSubject { coding, mathematics, general }

enum PostOffer { coffee, free }

class Post {
  const Post({
    required this.id,
    this.status = PostStatus.published,
    this.rawServerStatus,
    this.authorId,
    this.applicationCount,
    required this.title,
    this.topic,
    this.department,
    this.description,
    required this.authorName,
    required this.createdAt,
    required this.startsAt,
    required this.endsAt,
    required this.location,
    required this.type,
    required this.subject,
    required this.offer,
    this.coffeeCount = 0,
  });
  final String id;
  final PostStatus status;
  final String? rawServerStatus;
  final String? authorId;
  final int? applicationCount;
  final String title;
  // Nullable for older listings; Create Post requires a nonblank topic.
  final String? topic;
  // Legacy listings may not have an associated department.
  final String? department;
  final String? description;
  final String authorName;
  final DateTime createdAt;
  final DateTime startsAt;
  final DateTime endsAt;
  final String location;
  final PostType type;
  final PostSubject subject;
  final PostOffer offer;
  final int coffeeCount;

  Post copyWith({PostStatus? status}) => Post(
    id: id,
    authorId: authorId,
    applicationCount: applicationCount,
    title: title,
    topic: topic,
    department: department,
    description: description,
    authorName: authorName,
    createdAt: createdAt,
    startsAt: startsAt,
    endsAt: endsAt,
    location: location,
    type: type,
    subject: subject,
    offer: offer,
    coffeeCount: coffeeCount,
    rawServerStatus: rawServerStatus,
    status: status ?? this.status,
  );

  /// Time-based expiry only; this does not confirm lesson completion.
  bool isExpiredAt(DateTime now) => !endsAt.isAfter(now);

  String get typeLabel => switch (type) {
    PostType.tutoring => 'Özel Ders',
  };
  String get offerLabel =>
      offer == PostOffer.free ? 'Ücretsiz' : '$coffeeCount Kahve';
  String get dateLabel {
    const months = [
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${startsAt.day} ${months[startsAt.month - 1]} • ${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}';
  }
}
