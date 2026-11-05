import '../models/application.dart';

/// Role in this request, never a permanent account type.
enum RequestRole { student, teacher }

/// Maps one request row from the supplied backend contract. No envelope, HTTP
/// request, missing identity or full Post is fabricated here.
class RequestDto {
  RequestDto._(this._json);
  final Map<String, dynamic> _json;
  factory RequestDto.fromJson(Map<String, dynamic> json) =>
      RequestDto._(Map.unmodifiable(json));
  Application toDomain({
    required RequestRole role,
    required String currentUserId,
  }) {
    if (currentUserId.trim().isEmpty) {
      throw const FormatException('Oturum kimliği gerekli.');
    }
    final listing = _object(_json['listing'], 'listing');
    final counterpart = _object(_json['counterpart'], 'counterpart');
    final person = ApplicationPerson(
      id: _required(counterpart, 'id'),
      firstName: _string(counterpart, 'firstName'),
      lastNameInitial: _string(counterpart, 'lastNameInitial'),
      departmentId: _string(counterpart, 'departmentId'),
    );
    final status = _required(_json, 'status');
    final postId = _required(listing, 'id');
    return Application(
      id: _required(_json, 'id'),
      postId: postId,
      applicantId: role == RequestRole.teacher ? person.id : currentUserId,
      teacherId: role == RequestRole.teacher ? currentUserId : person.id,
      applicant: role == RequestRole.teacher ? person : null,
      teacher: role == RequestRole.student ? person : null,
      status: switch (status) {
        'PENDING' => ApplicationStatus.pending,
        'ACCEPTED' => ApplicationStatus.accepted,
        'REJECTED' => ApplicationStatus.rejected,
        'AUTO_CANCELLED' => ApplicationStatus.autoCancelled,
        _ => ApplicationStatus.unknown,
      },
      rawServerStatus: status,
      listing: ApplicationListing(
        id: postId,
        topic: _string(listing, 'topic'),
        startAt: _date(listing, 'startAt'),
        endAt: _date(listing, 'endAt'),
        tokenPrice: _amount(listing, 'tokenPrice'),
      ),
      agreedTokenAmount: _amount(_json, 'agreedTokenAmount'),
      createdAt: _date(_json, 'createdAt'),
      respondedAt: _date(_json, 'respondedAt'),
      conversationId: _string(_json, 'conversationId'),
      completionStatus: _string(_json, 'completionStatus'),
      studentCompletedAt: _date(_json, 'studentCompletedAt'),
      teacherCompletedAt: _date(_json, 'teacherCompletedAt'),
      confirmationDeadlineAt: _date(_json, 'confirmationDeadlineAt'),
      settledAt: _date(_json, 'settledAt'),
    );
  }

  static Map<String, dynamic> _object(Object? value, String key) {
    if (value is! Map<String, dynamic>) {
      throw FormatException('$key nesnesi gerekli.');
    }
    return value;
  }

  static String? _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('$key metin olmalı.');
    return value;
  }

  static String _required(Map<String, dynamic> json, String key) {
    final value = _string(json, key);
    if (value == null || value.trim().isEmpty) {
      throw FormatException('$key gerekli.');
    }
    return value;
  }

  static DateTime? _date(Map<String, dynamic> json, String key) {
    final value = _string(json, key);
    if (value == null) return null;
    final date = DateTime.tryParse(value);
    if (date == null) throw FormatException('$key geçersiz tarih.');
    return date;
  }

  static int? _amount(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! num ||
        !value.isFinite ||
        value < 0 ||
        value != value.truncateToDouble()) {
      throw FormatException('$key geçerli miktar olmalı.');
    }
    return value.toInt();
  }
}
