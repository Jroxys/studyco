enum PostType { tutoring }

enum PostSubject { coding, mathematics, general }

enum PostOffer { coffee, free }

class Post {
  const Post({
    required this.id,
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
