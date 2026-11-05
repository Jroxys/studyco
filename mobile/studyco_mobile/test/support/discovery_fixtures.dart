import 'package:studyco_mobile/features/posts/data/sample_posts.dart' as source;
import 'package:studyco_mobile/features/posts/models/post.dart';

/// Explicitly active test fixtures; historical design data remains unchanged.
List<Post> activeSamplePosts() =>
    source.samplePosts().map((post) {
      final start = DateTime(
        DateTime.now().year + 1,
        post.startsAt.month,
        post.startsAt.day,
        post.startsAt.hour,
        post.startsAt.minute,
      );
      return Post(
        id: post.id,
        authorId: 'fixture-owner-${post.id}',
        title: post.title,
        topic: post.topic,
        department: post.department,
        description: post.description,
        authorName: post.authorName,
        createdAt: post.createdAt,
        startsAt: start,
        endsAt: start.add(post.endsAt.difference(post.startsAt)),
        location: post.location,
        type: post.type,
        subject: post.subject,
        offer: post.offer,
        coffeeCount: post.coffeeCount,
      );
    }).toList();
