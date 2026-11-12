import 'package:flutter/foundation.dart';
import '../models/application.dart';
import '../../posts/models/post.dart';

class ApplicationFailure implements Exception {
  const ApplicationFailure(this.message);
  final String message;
}

/// Transport-independent seam for GET /api/v1/me/requests?role=student.
/// Remote implementations own DTO mapping, authorization and persistence.
abstract class ApplicationsRepository extends ChangeNotifier {
  List<Application> get applications;
  bool get isLocal => false;
  List<Application> forApplicant(String applicantId) => List.unmodifiable(
    applications.where((item) => item.applicantId == applicantId),
  );

  /// Listing eligibility, independent of an existing request. Duplicate requests
  /// must additionally be rejected by create. Remote adapters must verify their
  /// actual open/closed rules before opting in; a future date alone is not enough.
  bool isPostOpenForApplications(Post post) => false;
  bool canApply(Post post, {required String applicantId}) => false;
  Future<void> refresh({required String applicantId});
  List<Application> forOwner(String ownerId) => const [];
  Application? getForUser(String id, {required String userId}) {
    final matches = [
      ...forApplicant(userId),
      ...forOwner(userId),
    ].where((item) => item.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> refreshIncoming({required String ownerId}) => Future.error(
    const ApplicationFailure('Gelen başvurular şu anda yüklenemiyor.'),
  );
  bool canAccept(Application application, {required String ownerId}) => false;
  bool canReject(Application application, {required String ownerId}) => false;
  Future<void> accept(String id, {required String ownerId}) =>
      Future.error(const ApplicationFailure('Başvuru kabul edilemiyor.'));
  Future<void> reject(String id, {required String ownerId}) =>
      Future.error(const ApplicationFailure('Başvuru reddedilemiyor.'));

  /// Confirms only the authenticated participant. REST implementations send an
  /// empty body, use the JWT for authorization and publish the returned snapshot
  /// to the shared cache before completing. Failures must preserve that cache.
  Future<Application> confirmLesson(String id, {required String userId}) =>
      Future.error(const ApplicationFailure('Ders onayı şu anda yapılamıyor.'));

  Future<Application> create({
    required String postId,
    required String applicantId,
    ApplicationPerson? applicant,
  });
  bool canCancel(Application application, {required String applicantId}) =>
      false;
  Future<void> cancel(String applicationId, {required String applicantId}) =>
      Future.error(
        const ApplicationFailure(
          'Başvuru iptali bu veri kaynağında desteklenmiyor.',
        ),
      );
}
