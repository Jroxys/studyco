/// Domain states, not serialized API enum values. Unknown server values stay unknown.
enum ApplicationStatus { pending, accepted, rejected, autoCancelled, unknown }

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
  bool get isCompletedLesson =>
      status == ApplicationStatus.accepted &&
      !isLocallyCancelled &&
      completionStatus == 'COMPLETED';

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
  }) => Application(
    id: id,
    postId: postId,
    applicantId: applicantId,
    status: status ?? this.status,
    teacherId: teacherId,
    applicant: applicant,
    teacher: teacher,
    listing: listing,
    agreedTokenAmount: agreedTokenAmount,
    createdAt: createdAt,
    respondedAt: respondedAt ?? this.respondedAt,
    rawServerStatus: rawServerStatus,
    locallyCancelledAt: locallyCancelledAt ?? this.locallyCancelledAt,
    conversationId: conversationId,
    completionStatus: completionStatus,
    studentCompletedAt: studentCompletedAt,
    teacherCompletedAt: teacherCompletedAt,
    confirmationDeadlineAt: confirmationDeadlineAt,
    settledAt: settledAt,
  );
  Application cancelLocally(DateTime at) => copyWith(locallyCancelledAt: at);
}
