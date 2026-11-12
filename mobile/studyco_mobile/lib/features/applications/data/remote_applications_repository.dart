import '../../../core/api/api_client.dart';
import '../../posts/data/remote_posts_repository.dart';
import '../../posts/models/post.dart';
import '../domain/applications_repository.dart';
import '../models/application.dart';
import 'request_dto.dart';

/// Lesson requests from `/api/v1/me/requests` and `/api/v1/requests/:id/*`.
class RemoteApplicationsRepository extends ApplicationsRepository {
  RemoteApplicationsRepository({
    required this.api,
    required this.userId,
    required this.postsRepository,
  });

  final ApiClient api;
  final String userId;
  final RemotePostsRepository postsRepository;

  final Map<String, Application> _outgoing = {};
  final Map<String, Application> _incoming = {};
  bool _disposed = false;

  @override
  List<Application> get applications => List.unmodifiable(_outgoing.values);

  @override
  List<Application> forOwner(String ownerId) =>
      ownerId == userId ? List.unmodifiable(_incoming.values) : const [];

  Post? _post(String id) =>
      postsRepository.posts.where((post) => post.id == id).firstOrNull;

  @override
  bool isPostOpenForApplications(Post post) {
    final current = _post(post.id);
    return current != null &&
        current.status == PostStatus.published &&
        current.authorId?.trim().isNotEmpty == true &&
        current.startsAt.isAfter(DateTime.now());
  }

  @override
  bool canApply(Post post, {required String applicantId}) =>
      applicantId == userId &&
      isPostOpenForApplications(post) &&
      _post(post.id)!.authorId != applicantId &&
      !_outgoing.values.any((item) => item.postId == post.id);

  @override
  Future<void> refresh({required String applicantId}) async {
    if (applicantId != userId) return;
    await _load('student', _outgoing, RequestRole.student);
  }

  @override
  Future<void> refreshIncoming({required String ownerId}) async {
    if (ownerId != userId) return;
    await _load('teacher', _incoming, RequestRole.teacher);
  }

  Future<void> _load(
    String role,
    Map<String, Application> target,
    RequestRole as,
  ) async {
    final List<Map<String, dynamic>> rows;
    try {
      rows = await fetchAllPages(api, '/me/requests', query: {'role': role});
    } catch (error) {
      throw ApplicationFailure(
        apiErrorMessage(error, fallback: 'Başvurular yüklenemedi.'),
      );
    }
    target
      ..clear()
      ..addEntries(
        rows.map((json) {
          final item = RequestDto.fromJson(
            json,
          ).toDomain(role: as, currentUserId: userId);
          return MapEntry(item.id, item);
        }),
      );
    _notify();
  }

  @override
  Future<Application> create({
    required String postId,
    required String applicantId,
    ApplicationPerson? applicant,
  }) async {
    if (applicantId != userId) {
      throw const ApplicationFailure('Başvuran kimliği eşleşmiyor.');
    }
    final created = await _mutate(
      () => api.post('/listings/$postId/requests'),
      RequestRole.student,
      'Başvuru gönderilemedi.',
    );
    _outgoing[created.id] = created;
    _notify();
    return created;
  }

  @override
  bool canAccept(Application application, {required String ownerId}) =>
      _isActionable(application, ownerId);

  @override
  bool canReject(Application application, {required String ownerId}) =>
      _isActionable(application, ownerId);

  bool _isActionable(Application application, String ownerId) =>
      ownerId == userId &&
      application.teacherId == userId &&
      application.isPending &&
      (application.listing?.startAt?.isAfter(DateTime.now()) ?? false);

  @override
  Future<void> accept(String id, {required String ownerId}) async {
    final updated = await _mutate(
      () => api.post('/requests/$id/accept'),
      RequestRole.teacher,
      'Başvuru kabul edilemedi.',
    );
    _incoming[id] = updated;
    _notify();
    // Accepting books the listing and auto-cancels the other requests.
    await Future.wait([
      postsRepository.refreshQuietly(),
      _quiet(() => refreshIncoming(ownerId: userId)),
    ]);
  }

  @override
  Future<void> reject(String id, {required String ownerId}) async {
    final updated = await _mutate(
      () => api.post('/requests/$id/reject'),
      RequestRole.teacher,
      'Başvuru reddedilemedi.',
    );
    _incoming[id] = updated;
    _notify();
  }

  @override
  Future<Application> confirmLesson(String id, {required String userId}) async {
    final role =
        _incoming.containsKey(id) ? RequestRole.teacher : RequestRole.student;
    final updated = await _mutate(
      () => api.post('/requests/$id/confirm'),
      role,
      'Ders onayı kaydedilemedi.',
    );
    (role == RequestRole.teacher ? _incoming : _outgoing)[id] = updated;
    _notify();
    return updated;
  }

  Future<Application> _mutate(
    Future<dynamic> Function() call,
    RequestRole role,
    String fallback,
  ) async {
    try {
      final json = await call();
      return RequestDto.fromJson(
        json as Map<String, dynamic>,
      ).toDomain(role: role, currentUserId: userId);
    } on ApplicationFailure {
      rethrow;
    } catch (error) {
      throw ApplicationFailure(apiErrorMessage(error, fallback: fallback));
    }
  }

  Future<void> _quiet(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
