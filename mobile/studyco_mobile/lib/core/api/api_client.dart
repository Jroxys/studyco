import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Backend base URL. Override with `--dart-define=API_BASE_URL=http://host:3000`.
/// On the web the API is assumed on port 3000 of the host that served the
/// page, so a phone opening `http://COMPUTER_IP:8080` reaches that computer.
/// The Android emulator reaches the host machine through 10.0.2.2.
String defaultApiBaseUrl() {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  if (kIsWeb) {
    final page = Uri.base;
    final host = page.host.isEmpty ? '127.0.0.1' : page.host;
    return Uri(
      scheme: page.scheme == 'https' ? 'https' : 'http',
      host: host,
      port: 3000,
    ).toString();
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://127.0.0.1:3000';
}

/// A failed API call with the backend error code (or a transport code).
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

/// Turkish, user-facing text for backend error codes.
String apiErrorMessage(
  Object error, {
  String fallback = 'İşlem tamamlanamadı.',
}) {
  if (error is! ApiException) return fallback;
  return switch (error.code) {
    'NETWORK_ERROR' => 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.',
    'TIMEOUT' => 'Sunucu zamanında yanıt vermedi. Tekrar dene.',
    'INVALID_CREDENTIALS' => 'E-posta veya şifre hatalı.',
    'UNAUTHORIZED' => 'Oturumun sona erdi. Lütfen tekrar giriş yap.',
    'EMAIL_TAKEN' => 'Bu e-posta adresiyle kayıtlı bir hesap var.',
    'PHONE_TAKEN' => 'Bu telefon numarasıyla kayıtlı bir hesap var.',
    'UNDERAGE' => 'Kayıt için yaş sınırını karşılamıyorsun.',
    'RATE_LIMITED' ||
    'LOCKED' => 'Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.',
    'INSUFFICIENT_BALANCE' => 'Bakiyen bu ders için yetersiz.',
    'TIME_CONFLICT' => 'Bu saatte başka bir dersin var.',
    'ALREADY_REQUESTED' => 'Bu ilana zaten başvurdun.',
    'CANNOT_REQUEST_OWN_LISTING' => 'Kendi ilanına başvuramazsın.',
    'LISTING_NOT_PUBLISHED' ||
    'LISTING_ALREADY_BOOKED' => 'Bu ilan artık başvuruya açık değil.',
    'LISTING_EXPIRED' => 'Süresi dolan ilanlara başvuru yapılamaz.',
    'LISTING_START_IN_PAST' => 'Ders başlangıcı gelecekte olmalı.',
    'REQUEST_NOT_PENDING' => 'Bu başvuru artık beklemede değil.',
    'CONFIRMATION_TOO_EARLY' => 'Ders bitmeden onay verilemez.',
    'CONFIRMATION_WINDOW_CLOSED' => 'Onay süresi doldu.',
    'ALREADY_REVIEWED' => 'Bu ders için zaten değerlendirme yaptın.',
    'REVIEW_REQUIRES_COMPLETED_LESSON' =>
      'Değerlendirme yalnızca tamamlanan dersler için yapılabilir.',
    'COURSE_INACTIVE' => 'Seçilen ders artık aktif değil.',
    'LOCATION_INACTIVE_OR_UNKNOWN' => 'Seçilen konum artık kullanılamıyor.',
    'EMAIL_NOT_VERIFIED' =>
      'Bu işlem için e-posta adresini doğrulaman gerekiyor.',
    'VALIDATION_ERROR' =>
      'Girilen bilgiler geçersiz. Kontrol edip tekrar dene.',
    'INTERNAL' => 'Sunucuda beklenmeyen bir hata oluştu. Tekrar dene.',
    _ => error.message.trim().isEmpty ? fallback : error.message,
  };
}

/// Supplies and renews the bearer token. Implemented by [AuthSession].
abstract interface class AccessTokenProvider {
  String? get accessToken;

  /// Returns true when a new access token was obtained.
  Future<bool> refreshAccessToken();

  /// Called when the session can no longer be renewed.
  void onUnauthorized();
}

/// Small JSON client for `/api/v1`. Retries once after a 401 by refreshing.
class ApiClient {
  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  }) : baseUrl = (baseUrl ?? defaultApiBaseUrl()).replaceAll(
         RegExp(r'/+$'),
         '',
       ),
       _http = httpClient ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _http;
  AccessTokenProvider? tokens;

  Uri uri(String path, [Map<String, Object?>? query]) {
    final params = <String, String>{
      for (final entry in (query ?? const {}).entries)
        if (entry.value != null) entry.key: '${entry.value}',
    };
    return Uri.parse(
      '$baseUrl/api/v1$path',
    ).replace(queryParameters: params.isEmpty ? null : params);
  }

  Future<dynamic> get(
    String path, {
    Map<String, Object?>? query,
    bool auth = true,
  }) => _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);

  Future<dynamic> patch(String path, {Object? body, bool auth = true}) =>
      _send('PATCH', path, body: body, auth: auth);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    required bool auth,
    bool retried = false,
  }) async {
    final request = http.Request(method, uri(path, query));
    request.headers['accept'] = 'application/json';
    if (body != null) {
      request.headers['content-type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final token = auth ? tokens?.accessToken : null;
    if (token != null) request.headers['authorization'] = 'Bearer $token';

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      );
    } on TimeoutException {
      throw const ApiException('TIMEOUT', 'İstek zaman aşımına uğradı.');
    } catch (_) {
      throw const ApiException('NETWORK_ERROR', 'Sunucuya ulaşılamadı.');
    }

    if (response.statusCode == 401 && auth && !retried && tokens != null) {
      if (await tokens!.refreshAccessToken()) {
        return _send(
          method,
          path,
          query: query,
          body: body,
          auth: auth,
          retried: true,
        );
      }
      tokens!.onUnauthorized();
    }

    final text = utf8.decode(response.bodyBytes);
    final decoded = text.isEmpty ? null : _tryDecode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
    if (error is Map<String, dynamic>) {
      throw ApiException(
        '${error['code'] ?? 'HTTP_${response.statusCode}'}',
        '${error['message'] ?? ''}',
        statusCode: response.statusCode,
      );
    }
    throw ApiException(
      response.statusCode == 429
          ? 'RATE_LIMITED'
          : 'HTTP_${response.statusCode}',
      '',
      statusCode: response.statusCode,
    );
  }

  static Object? _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  void close() => _http.close();
}

/// Reads all pages of a `{ items, nextCursor }` endpoint, up to [maxPages].
Future<List<Map<String, dynamic>>> fetchAllPages(
  ApiClient api,
  String path, {
  Map<String, Object?> query = const {},
  int pageSize = 50,
  int maxPages = 10,
}) async {
  final items = <Map<String, dynamic>>[];
  String? cursor;
  for (var page = 0; page < maxPages; page++) {
    final json = await api.get(
      path,
      query: {...query, 'limit': pageSize, 'cursor': cursor},
    );
    if (json is! Map<String, dynamic> || json['items'] is! List) {
      throw const FormatException('Beklenmeyen sayfa yanıtı.');
    }
    items.addAll((json['items'] as List).cast<Map<String, dynamic>>());
    cursor = json['nextCursor'] as String?;
    if (cursor == null) break;
  }
  return items;
}
