import '../../posts/domain/posts_repository.dart';
import '../../posts/models/post.dart';
import '../domain/applications_repository.dart';
import '../domain/lesson_confirmation.dart';
import '../models/application.dart';

/// Session-only mock. Does not claim any remote mutation or status contract.
class InMemoryApplicationsRepository extends ApplicationsRepository {
  InMemoryApplicationsRepository({
    required this.postsRepository,
    Iterable<Application> initialApplications = const [],
    DateTime Function()? clock,
  }) : _applications = List.of(initialApplications),
       _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  final PostsRepository postsRepository;
  final List<Application> _applications;
  int _sequence = 0;
  @override
  bool get isLocal => true;
  @override
  List<Application> get applications => List.unmodifiable(_applications);
  @override
  bool isPostOpenForApplications(Post post) {
    final matches = postsRepository.posts.where((item) => item.id == post.id);
    if (matches.isEmpty) return false;
    final current = matches.first;
    return current.status == PostStatus.published &&
        current.authorId?.trim().isNotEmpty == true &&
        current.startsAt.isAfter(DateTime.now()) &&
        current.endsAt.isAfter(current.startsAt);
  }

  @override
  bool canApply(Post post, {required String applicantId}) =>
      applicantId.trim().isNotEmpty &&
      isPostOpenForApplications(post) &&
      postsRepository.posts.firstWhere((item) => item.id == post.id).authorId !=
          applicantId;

  @override
  Future<void> refresh({required String applicantId}) async {}
  @override
  Future<Application> create({
    required String postId,
    required String applicantId,
    ApplicationPerson? applicant,
  }) async {
    if (applicant != null && applicant.id != applicantId) {
      throw const ApplicationFailure('Başvuran kimliği eşleşmiyor.');
    }
    if (applicantId.trim().isEmpty) {
      throw const ApplicationFailure('Başvuru için kullanıcı bilgisi gerekli.');
    }
    final matches = postsRepository.posts.where((post) => post.id == postId);
    if (matches.isEmpty) {
      throw const ApplicationFailure('İlan artık görüntülenemiyor.');
    }
    final post = matches.first;
    if (post.authorId == null || post.authorId!.trim().isEmpty) {
      throw const ApplicationFailure(
        'İlan sahibinin kimliği doğrulanamadığı için başvuru yapılamıyor.',
      );
    }
    if (post.authorId == applicantId) {
      throw const ApplicationFailure('Kendi ilanına başvuramazsın.');
    }
    if (post.isExpiredAt(DateTime.now())) {
      throw const ApplicationFailure(
        'Süresi dolan ilanlara başvuru yapılamaz.',
      );
    }
    if (_applications.any(
      (item) => item.postId == postId && item.applicantId == applicantId,
    )) {
      throw const ApplicationFailure('Bu ilana zaten başvurdun.');
    }
    if (!canApply(post, applicantId: applicantId)) {
      throw const ApplicationFailure('Bu ilan şu anda başvuruya açık değil.');
    }
    final now = DateTime.now().toUtc();
    String id;
    do {
      id = 'local-application-${now.microsecondsSinceEpoch}-${_sequence++}';
    } while (_applications.any((item) => item.id == id));
    final application = Application(
      id: id,
      postId: postId,
      applicantId: applicantId,
      status: ApplicationStatus.pending,
      teacherId: post.authorId,
      applicant: applicant,
      agreedTokenAmount: post.offer == PostOffer.free ? 0 : post.coffeeCount,
      listing: ApplicationListing(
        id: post.id,
        topic: post.topic,
        startAt: post.startsAt,
        endAt: post.endsAt,
        tokenPrice: post.offer == PostOffer.free ? 0 : post.coffeeCount,
      ),
      createdAt: now,
    );
    _applications.add(application);
    notifyListeners();
    return application;
  }

  @override
  bool canCancel(Application application, {required String applicantId}) {
    final matches = _applications.where((item) => item.id == application.id);
    if (matches.isEmpty) return false;
    final current = matches.first;
    final posts = postsRepository.posts.where(
      (post) => post.id == current.postId,
    );
    return current.applicantId == applicantId &&
        !current.isLocallyCancelled &&
        current.status == ApplicationStatus.pending &&
        posts.isNotEmpty &&
        !posts.first.isExpiredAt(DateTime.now());
  }

  @override
  Future<void> cancel(
    String applicationId, {
    required String applicantId,
  }) async {
    final index = _applications.indexWhere((item) => item.id == applicationId);
    if (index < 0 ||
        !canCancel(_applications[index], applicantId: applicantId)) {
      throw const ApplicationFailure('Bu başvuru iptal edilemiyor.');
    }
    _applications[index] = _applications[index].cancelLocally(
      DateTime.now().toUtc(),
    );
    notifyListeners();
  }

  Post? _post(String id) {
    final matches = postsRepository.posts.where((item) => item.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  List<Application> forOwner(String ownerId) => List.unmodifiable(
    _applications.where(
      (item) => (_post(item.postId)?.authorId ?? item.teacherId) == ownerId,
    ),
  );
  @override
  Future<void> refreshIncoming({required String ownerId}) async {}
  Application? _current(String id) {
    final matches = _applications.where((item) => item.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  bool canReject(Application application, {required String ownerId}) {
    final current = _current(application.id);
    return ownerId.trim().isNotEmpty &&
        current != null &&
        current.isPending &&
        _post(current.postId)?.authorId == ownerId;
  }

  @override
  bool canAccept(Application application, {required String ownerId}) {
    final current = _current(application.id);
    if (current == null || !canReject(current, ownerId: ownerId)) return false;
    final post = _post(current.postId)!;
    return current.applicantId != ownerId && isPostOpenForApplications(post);
  }

  void _checkConflicts(Application candidate, Post lesson) {
    for (final accepted in _applications.where(
      (item) =>
          item.status == ApplicationStatus.accepted && !item.isLocallyCancelled,
    )) {
      final other = _post(accepted.postId);
      final start = other?.startsAt ?? accepted.listing?.startAt;
      final end = other?.endsAt ?? accepted.listing?.endAt;
      final otherOwner = other?.authorId ?? accepted.teacherId;
      final sharesParticipant = {candidate.applicantId, lesson.authorId}.any(
        (id) => id != null && (id == accepted.applicantId || id == otherOwner),
      );
      if (!sharesParticipant) continue;
      if (start == null || end == null) {
        throw const ApplicationFailure(
          'Kabul edilmiş derslerin saat bilgisi doğrulanamıyor.',
        );
      }
      if (lesson.startsAt.isBefore(end) && start.isBefore(lesson.endsAt)) {
        throw const ApplicationFailure(
          'Öğrencinin veya ilan sahibinin ders saatleri çakışıyor.',
        );
      }
    }
  }

  @override
  Future<void> accept(String id, {required String ownerId}) async {
    final current = _current(id);
    if (current == null || !canAccept(current, ownerId: ownerId)) {
      throw const ApplicationFailure(
        'Başvuru artık kabul edilemiyor. Durumu ve ders tarihini kontrol et.',
      );
    }
    final lesson = _post(current.postId)!;
    _checkConflicts(current, lesson);
    final now = DateTime.now().toUtc();
    final next =
        _applications.map((item) {
          if (item.id == id) {
            return item.copyWith(
              status: ApplicationStatus.accepted,
              respondedAt: now,
              lessonCompletionStatus: LessonCompletionStatus.notStarted,
              confirmationDeadlineAt: lesson.endsAt.add(
                const Duration(hours: 24),
              ),
              listing: ApplicationListing(
                id: lesson.id,
                topic: lesson.topic,
                startAt: lesson.startsAt,
                endAt: lesson.endsAt,
                tokenPrice: item.listing?.tokenPrice ?? item.agreedTokenAmount,
              ),
            );
          }
          if (item.postId == current.postId && item.isPending) {
            return item.copyWith(
              status: ApplicationStatus.autoCancelled,
              respondedAt: now,
            );
          }
          return item;
        }).toList();
    postsRepository.commitBooking(
      lesson.id,
      ownerId: ownerId,
      commitApplications: () {
        _applications
          ..clear()
          ..addAll(next);
      },
    );
    notifyListeners();
  }

  @override
  Future<Application> confirmLesson(String id, {required String userId}) async {
    final current = _current(id);
    final participant = current?.participantFor(userId);
    final postOwner = current == null ? null : _post(current.postId)?.authorId;
    if (current == null ||
        participant == null ||
        (postOwner != null && postOwner != current.teacherId)) {
      throw const ApplicationFailure('Bu ders için onay verme yetkin yok.');
    }
    if (current.status != ApplicationStatus.accepted ||
        current.isLocallyCancelled) {
      throw const ApplicationFailure(
        'Yalnızca kabul edilen dersler onaylanabilir.',
      );
    }
    if (current.lessonCompletionStatus == LessonCompletionStatus.manualReview) {
      throw const ApplicationFailure('Bu ders inceleme bekliyor.');
    }
    // A retry of a recorded confirmation never updates timestamps or notifies.
    if (current.completedAtBy(participant) != null) return current;

    final now = _clock().toUtc();
    final phase = LessonConfirmationPhase.forUser(
      current,
      userId: userId,
      now: now,
    );
    final error = switch (phase) {
      LessonConfirmationPhase.open => null,
      LessonConfirmationPhase.lessonPending => 'Ders bitmeden onay veremezsin.',
      LessonConfirmationPhase.expired => 'Dersin onay süresi doldu.',
      LessonConfirmationPhase.completed => 'Bu ders zaten tamamlandı.',
      _ => 'Dersin onay bilgileri doğrulanamadı.',
    };
    if (error != null) throw ApplicationFailure(error);

    final student = participant == LessonParticipant.student;
    final otherAt =
        student ? current.teacherCompletedAt : current.studentCompletedAt;
    final updated = current.copyWith(
      studentCompletedAt: student ? now : null,
      teacherCompletedAt: student ? null : now,
      lessonCompletionStatus:
          otherAt == null
              ? LessonCompletionStatus.awaitingConfirmation
              : LessonCompletionStatus.completed,
    );
    _applications[_applications.indexOf(current)] = updated;
    notifyListeners();
    return updated;
  }

  @override
  Future<void> reject(String id, {required String ownerId}) async {
    final current = _current(id);
    if (current == null || !canReject(current, ownerId: ownerId)) {
      throw const ApplicationFailure(
        'Başvuru artık reddedilemiyor. Durumu yenileyip tekrar dene.',
      );
    }
    final index = _applications.indexWhere((item) => item.id == id);
    _applications[index] = current.copyWith(
      status: ApplicationStatus.rejected,
      respondedAt: DateTime.now().toUtc(),
    );
    notifyListeners();
  }
}
