import '../../../core/api/api_client.dart';
import '../../../core/data/academic_catalog.dart';
import '../../../core/data/remote_catalog.dart';
import '../../applications/data/remote_applications_repository.dart';
import '../domain/location_catalog.dart';
import '../domain/posts_repository.dart';
import '../models/post.dart';

/// Listings from `/api/v1/listings` and `/api/v1/me/listings`.
class RemotePostsRepository extends PostsRepository {
  RemotePostsRepository({
    required this.api,
    required this.userId,
    required this.academicCatalog,
    required this.locationCatalog,
  });

  final ApiClient api;
  final String userId;
  final AcademicCatalog Function() academicCatalog;
  final LocationCatalog Function() locationCatalog;

  final Map<String, Post> _posts = {};
  bool _disposed = false;

  late final RemoteApplicationsRepository _applications =
      RemoteApplicationsRepository(
        api: api,
        userId: userId,
        postsRepository: this,
      );

  @override
  RemoteApplicationsRepository get applicationsRepository => _applications;

  @override
  List<Post> get posts => List.unmodifiable(_posts.values);

  @override
  Future<void> refresh() async {
    final results = await Future.wait([
      fetchAllPages(api, '/listings', maxPages: 4),
      api.get('/me/listings'),
    ]);
    final next = <String, Post>{};
    for (final json in results[0] as List<Map<String, dynamic>>) {
      final post = postFromListing(json);
      next[post.id] = post;
    }
    for (final json in (results[1] as List).cast<Map<String, dynamic>>()) {
      final post = postFromListing(json);
      next[post.id] = post;
    }
    _posts
      ..clear()
      ..addAll(next);
    _notify();
  }

  @override
  Future<void> addPost(Post post) async {
    final department = academicCatalog().findDepartment(post.department);
    final course = department?.courses.where(
      (course) => academicKey(course.title) == academicKey(post.title),
    );
    final courseId = course == null || course.isEmpty ? null : course.first.id;
    final locationId = locationCatalog().findByName(post.location)?.id;
    if (courseId == null || locationId == null) {
      throw StateError(
        'Ders veya konum katalogda bulunamadı. Listeden bir ders seçin.',
      );
    }
    final created = await api.post(
      '/listings',
      body: {
        'courseId': courseId,
        'locationId': locationId,
        'topic': (post.topic ?? post.title).trim(),
        if (post.description?.trim().isNotEmpty == true)
          'description': post.description!.trim(),
        'startAt': post.startsAt.toUtc().toIso8601String(),
        'endAt': post.endsAt.toUtc().toIso8601String(),
        'tokenPrice': post.offer == PostOffer.free ? 0 : post.coffeeCount,
      },
    );
    final saved = postFromListing(created as Map<String, dynamic>);
    _posts[saved.id] = saved;
    _notify();
  }

  /// Refreshes after a server transaction changed listing state (e.g. accept).
  Future<void> refreshQuietly() async {
    try {
      await refresh();
    } catch (_) {
      // Keep the last confirmed snapshot; screens offer manual refresh.
    }
  }

  Post postFromListing(Map<String, dynamic> json) {
    final teacher = json['teacher'] as Map<String, dynamic>;
    final status = json['status'] as String;
    final price = (json['tokenPrice'] as num).toInt();
    final courseName = json['courseName'] as String;
    final departmentId = teacher['departmentId'] as String?;
    final departmentName =
        academicCatalog().departments
            .where((d) => d.id == departmentId)
            .map((d) => d.name)
            .firstOrNull;
    final initial = (teacher['lastNameInitial'] as String? ?? '').trim();
    final startsAt = DateTime.parse(json['startAt'] as String).toLocal();
    return Post(
      id: json['id'] as String,
      status: switch (status) {
        'PUBLISHED' => PostStatus.published,
        'BOOKED' => PostStatus.booked,
        _ => PostStatus.unknown,
      },
      rawServerStatus: status,
      authorId: teacher['id'] as String,
      applicationCount: (json['pendingRequestCount'] as num?)?.toInt(),
      title: courseName,
      topic: json['topic'] as String?,
      department: departmentName,
      description: json['description'] as String?,
      authorName:
          initial.isEmpty
              ? teacher['firstName'] as String
              : '${teacher['firstName']} $initial.',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
          startsAt,
      startsAt: startsAt,
      endsAt: DateTime.parse(json['endAt'] as String).toLocal(),
      location: json['locationName'] as String,
      type: PostType.tutoring,
      subject: subjectFor(courseName),
      offer: price == 0 ? PostOffer.free : PostOffer.coffee,
      coffeeCount: price,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _applications.dispose();
    super.dispose();
  }
}
