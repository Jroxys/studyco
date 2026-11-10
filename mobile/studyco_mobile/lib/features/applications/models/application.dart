/// Domain states, not serialized API enum values. Unknown server values stay unknown.
enum ApplicationStatus { pending, accepted, rejected, autoCancelled, unknown }

/// Separate from the request decision. Unknown API values fail closed.
enum LessonCompletionStatus {
  notStarted('NOT_STARTED'),
  awaitingConfirmation('AWAITING_CONFIRMATION'),
  completed('COMPLETED'),
  manualReview('MANUAL_REVIEW');

  const LessonCompletionStatus(this.apiValue);
  final String apiValue;

  static LessonCompletionStatus? fromApi(String? value) => switch (value) {
    'NOT_STARTED' => notStarted,
    'AWAITING_CONFIRMATION' => awaitingConfirmation,
    'COMPLETED' => completed,
    'MANUAL_REVIEW' => manualReview,
    _ => null,
  };
}

enum LessonParticipant { student, teacher }

enum ApplicationFilter {
  all('Tümü'),
  pending('Beklemede'),
  accepted('Kabul Edildi'),
  rejected('Reddedildi');

  const ApplicationFilter(this.label);
  final String label;
  bool matches(Application application) => switch (this) {
    all => true,
    pending =>
      !application.isLocallyCancelled &&
          application.status == ApplicationStatus.pending,
    accepted =>
      !application.isLocallyCancelled &&
          application.status == ApplicationStatus.accepted,
    rejected =>
      !application.isLocallyCancelled &&
          application.status == ApplicationStatus.rejected,
  };
}

/// Available counterpart fields only; no full surname or department name invented.
class ApplicationPerson {
  const ApplicationPerson({
    required this.id,
    this.firstName,
    this.lastNameInitial,
    this.departmentId,
  });
  final String id;
  final String? firstName;
  final String? lastNameInitial;
  final String? departmentId;
  String? get displayName {
    final first = firstName?.trim();
    if (first == null || first.isEmpty) return null;
    final initial = lastNameInitial?.trim();
    return initial == null || initial.isEmpty
        ? first
        : '$first ${initial.replaceAll('.', '')}.';
  }
}

/// Partial API listing projection; never manufacture a full Post from missing data.
class ApplicationListing {
  const ApplicationListing({
    required this.id,
    this.topic,
    this.startAt,
    this.endAt,
    this.tokenPrice,
  });
  final String id;
  final String? topic;
  final DateTime? startAt;
  final DateTime? endAt;
  final int? tokenPrice;
}

class Application {
  const Application({
    required this.id,
    required this.postId,
    required this.applicantId,
    required this.status,
    this.teacherId,
    this.applicant,
    this.teacher,
    this.listing,
    this.agreedTokenAmount,
    this.createdAt,
    this.respondedAt,
    this.rawServerStatus,
    this.locallyCancelledAt,
    this.conversationId,
    this.completionStatus,
    this.studentCompletedAt,
    this.teacherCompletedAt,
    this.confirmationDeadlineAt,
    this.settledAt,
  });
  final String id;
  final String postId;
  final String applicantId;
  final ApplicationStatus status;
  final String? teacherId;
  final ApplicationPerson? applicant;
  final ApplicationPerson? teacher;
  final ApplicationListing? listing;
  final int? agreedTokenAmount;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final String? rawServerStatus;
  final DateTime? locallyCancelledAt;
  final String? conversationId;
  final String? completionStatus;
  final DateTime? studentCompletedAt;
  final DateTime? teacherCompletedAt;
  final DateTime? confirmationDeadlineAt;
  final DateTime? settledAt;
  LessonCompletionStatus? get lessonCompletionStatus =>
      LessonCompletionStatus.fromApi(completionStatus);

  LessonParticipant? participantFor(String userId) {
    final owner = teacherId;
    if (owner == null ||
        owner.trim().isEmpty ||
        applicantId.trim().isEmpty ||
        owner == applicantId) {
      return null;
    }
    if (userId == applicantId) return LessonParticipant.student;
    if (userId == owner) return LessonParticipant.teacher;
    return null;
  }

  DateTime? completedAtBy(LessonParticipant participant) =>
      switch (participant) {
        LessonParticipant.student => studentCompletedAt,
        LessonParticipant.teacher => teacherCompletedAt,
      };

  bool get isCompletedLesson =>
      status == ApplicationStatus.accepted &&
      !isLocallyCancelled &&
      lessonCompletionStatus == LessonCompletionStatus.completed;

  bool get isLocallyCancelled => locallyCancelledAt != null;
  bool get isPending =>
      status == ApplicationStatus.pending && !isLocallyCancelled;
  String get statusLabel =>
      isLocallyCancelled
          ? 'İptal Edildi'
          : switch (status) {
            ApplicationStatus.pending => 'Beklemede',
            ApplicationStatus.accepted => 'Kabul Edildi',
            ApplicationStatus.rejected => 'Reddedildi',
            ApplicationStatus.autoCancelled => 'Otomatik İptal Edildi',
            ApplicationStatus.unknown => 'Durum bilgisi mevcut değil',
          };
  Application copyWith({
    ApplicationStatus? status,
    DateTime? respondedAt,
    DateTime? locallyCancelledAt,
    ApplicationListing? listing,
    LessonCompletionStatus? lessonCompletionStatus,
    DateTime? studentCompletedAt,
    DateTime? teacherCompletedAt,
    DateTime? confirmationDeadlineAt,
  }) => Application(
    id: id,
    postId: postId,
    applicantId: applicantId,
    status: status ?? this.status,
    teacherId: teacherId,
    applicant: applicant,
    teacher: teacher,
    listing: listing ?? this.listing,
    agreedTokenAmount: agreedTokenAmount,
    createdAt: createdAt,
    respondedAt: respondedAt ?? this.respondedAt,
    rawServerStatus: rawServerStatus,
    locallyCancelledAt: locallyCancelledAt ?? this.locallyCancelledAt,
    conversationId: conversationId,
    completionStatus: lessonCompletionStatus?.apiValue ?? completionStatus,
    studentCompletedAt: studentCompletedAt ?? this.studentCompletedAt,
    teacherCompletedAt: teacherCompletedAt ?? this.teacherCompletedAt,
    confirmationDeadlineAt:
        confirmationDeadlineAt ?? this.confirmationDeadlineAt,
    settledAt: settledAt,
  );
  Application cancelLocally(DateTime at) => copyWith(locallyCancelledAt: at);
}
