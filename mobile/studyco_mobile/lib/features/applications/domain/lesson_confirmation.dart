import '../models/application.dart';

/// A projection of the current snapshot. Clock changes only affect button
/// eligibility; terminal states always come from the repository.
enum LessonConfirmationPhase {
  unavailable,
  lessonPending,
  open,
  waitingForOther,
  expired,
  completed,
  manualReview;

  static DateTime? closesAt(Application application) {
    final end = application.listing?.endAt;
    final deadline = application.confirmationDeadlineAt;
    if (end == null || deadline == null || !deadline.isAfter(end)) return null;
    final limit = end.add(const Duration(hours: 24));
    return deadline.isBefore(limit) ? deadline : limit;
  }

  static LessonConfirmationPhase forUser(
    Application application, {
    required String userId,
    required DateTime now,
  }) {
    if (application.status != ApplicationStatus.accepted ||
        application.isLocallyCancelled) {
      return unavailable;
    }
    final status = application.lessonCompletionStatus;
    if (status == LessonCompletionStatus.completed) return completed;
    if (status == LessonCompletionStatus.manualReview) return manualReview;
    final participant = application.participantFor(userId);
    final end = application.listing?.endAt;
    if (status == null || participant == null || end == null) {
      return unavailable;
    }
    if (now.isBefore(end)) return lessonPending;
    final deadline = closesAt(application);
    if (deadline == null) return unavailable;
    if (!now.isBefore(deadline)) return expired;
    return application.completedAtBy(participant) == null
        ? open
        : waitingForOther;
  }
}
