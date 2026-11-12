import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyco_mobile/core/api/api_client.dart';
import 'package:studyco_mobile/core/session/auth_session.dart';

const departmentId = '11111111-1111-4111-8111-111111111111';
const courseId = '22222222-2222-4222-8222-222222222222';
const locationId = '33333333-3333-4333-8333-333333333333';
const userId = '44444444-4444-4444-8444-444444444444';
const teacherId = '55555555-5555-4555-8555-555555555555';
const listingId = '66666666-6666-4666-8666-666666666666';

/// In-memory stand-in for the StudyCo REST API, enough for app-level tests.
class FakeBackend {
  FakeBackend({this.password = 'secret123'});

  final String password;
  final List<http.Request> requests = [];
  final List<Map<String, dynamic>> listings = [];
  final List<Map<String, dynamic>> studentRequests = [];
  bool online = true;

  late final AuthSession session = AuthSession(
    api: ApiClient(baseUrl: 'http://api.test', httpClient: MockClient(_handle)),
    store: MemoryRefreshTokenStore(),
  );

  Map<String, dynamic> get user => {
    'id': userId,
    'firstName': 'Ayşe',
    'lastName': 'Yılmaz',
    'birthDate': '2003-01-01',
    'email': 'student@example.com',
    'phone': '05551234567',
    'departmentId': departmentId,
    'emailVerified': true,
  };

  Map<String, dynamic> listing({
    String id = listingId,
    String teacher = teacherId,
    String topic = 'Döngüler',
  }) {
    final start = DateTime.now().toUtc().add(const Duration(days: 2));
    return {
      'id': id,
      'courseId': courseId,
      'courseName': 'Algoritma ve Programlama',
      'locationId': locationId,
      'locationName': 'Espressolab',
      'topic': topic,
      'description': null,
      'startAt': start.toIso8601String(),
      'endAt': start.add(const Duration(hours: 1)).toIso8601String(),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'tokenPrice': 1,
      'status': 'PUBLISHED',
      'teacher': {
        'id': teacher,
        'firstName': 'Mehmet',
        'lastNameInitial': 'K',
        'departmentId': departmentId,
        'ratingAverage': null,
        'ratingCount': 0,
      },
    };
  }

  http.Response _json(Object? body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  http.Response _error(int status, String code) => _json({
    'error': {'code': code, 'message': code},
  }, status);

  Map<String, dynamic> get _tokens => {
    'user': user,
    'accessToken': 'access-token',
    'refreshToken': 'r' * 40,
  };

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    if (!online) throw http.ClientException('offline');
    final path = request.url.path.replaceFirst('/api/v1', '');
    final body = request.body.isEmpty ? null : jsonDecode(request.body);
    final authed = request.headers['authorization'] == 'Bearer access-token';
    final key = '${request.method} $path';

    if (key == 'POST /auth/login') {
      final ok =
          body['email'] == 'student@example.com' &&
          body['password'] == password;
      return ok ? _json(_tokens) : _error(401, 'INVALID_CREDENTIALS');
    }
    if (key == 'POST /auth/register') {
      if (body['departmentId'] != departmentId ||
          body['termsAccepted'] != true) {
        return _error(400, 'VALIDATION_ERROR');
      }
      return _json(_tokens, 201);
    }
    if (key == 'POST /auth/logout') return http.Response('', 204);
    if (key == 'GET /departments') {
      return _json([
        {'id': departmentId, 'name': 'Bilgisayar Mühendisliği'},
      ]);
    }
    if (!authed) return _error(401, 'UNAUTHORIZED');

    switch (key) {
      case 'GET /courses':
        return _json([
          {
            'id': courseId,
            'departmentId': departmentId,
            'name': 'Algoritma ve Programlama',
          },
        ]);
      case 'GET /locations':
        return _json([
          {
            'id': locationId,
            'name': 'Espressolab',
            'description': null,
            'latitude': null,
            'longitude': null,
          },
        ]);
      case 'GET /me':
        return _json(user);
      case 'GET /listings':
        return _json({
          'items': listings.where((l) => l['teacher']['id'] != userId).toList(),
          'nextCursor': null,
        });
      case 'GET /me/listings':
        return _json([
          for (final l in listings)
            if (l['teacher']['id'] == userId) {...l, 'pendingRequestCount': 0},
        ]);
      case 'GET /me/requests':
        final role = request.url.queryParameters['role'];
        return _json({
          'items': role == 'student' ? studentRequests : [],
          'nextCursor': null,
        });
      case 'POST /listings':
        final created = listing(
          id: '77777777-7777-4777-8777-77777777777${listings.length}',
          teacher: userId,
          topic: body['topic'] as String,
        );
        listings.add(created);
        return _json(created, 201);
    }
    final apply = RegExp(r'^POST /listings/([^/]+)/requests$').firstMatch(key);
    if (apply != null) {
      final target = listings.firstWhere((l) => l['id'] == apply.group(1));
      final created = {
        'id': '88888888-8888-4888-8888-88888888888${studentRequests.length}',
        'status': 'PENDING',
        'completionStatus': 'NOT_STARTED',
        'agreedTokenAmount': null,
        'respondedAt': null,
        'autoCancelReason': null,
        'studentCompletedAt': null,
        'teacherCompletedAt': null,
        'confirmationDeadlineAt': null,
        'settledAt': null,
        'settlementBasis': null,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'listing': {
          'id': target['id'],
          'topic': target['topic'],
          'startAt': target['startAt'],
          'endAt': target['endAt'],
          'tokenPrice': target['tokenPrice'],
        },
        'counterpart': {
          'id': target['teacher']['id'],
          'firstName': 'Mehmet',
          'lastNameInitial': 'K',
          'departmentId': departmentId,
        },
        'conversationId': null,
      };
      studentRequests.add(created);
      return _json(created, 201);
    }
    return _error(404, 'NOT_FOUND');
  }
}
