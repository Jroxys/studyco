import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/api_client.dart';

/// Version of the terms text shown on the registration screen.
const currentTermsVersion = '2026-11';

/// The authenticated account as returned by `/auth/*` and `/me`.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.departmentId,
    required this.birthDate,
    required this.emailVerified,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String,
    departmentId: json['departmentId'] as String,
    birthDate: json['birthDate'] as String,
    emailVerified: json['emailVerified'] as bool,
  );

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String departmentId;
  final String birthDate;
  final bool emailVerified;
}

class RegistrationRequest {
  const RegistrationRequest({
    required this.firstName,
    required this.lastName,
    required this.birthDate,
    required this.email,
    required this.phone,
    required this.password,
    required this.departmentId,
  });

  final String firstName;
  final String lastName;
  final DateTime birthDate;
  final String email;
  final String phone;
  final String password;
  final String departmentId;

  Map<String, Object?> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'birthDate':
        '${birthDate.year.toString().padLeft(4, '0')}-'
        '${birthDate.month.toString().padLeft(2, '0')}-'
        '${birthDate.day.toString().padLeft(2, '0')}',
    'email': email,
    'phone': phone,
    'password': password,
    'departmentId': departmentId,
    'termsAccepted': true,
    'termsVersion': currentTermsVersion,
  };
}

/// Persists only the refresh token. Access tokens stay in memory.
abstract interface class RefreshTokenStore {
  Future<String?> read();
  Future<void> write(String? token);
}

class SecureRefreshTokenStore implements RefreshTokenStore {
  SecureRefreshTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();
  static const _key = 'studyco.refreshToken';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String? token) async {
    try {
      token == null
          ? await _storage.delete(key: _key)
          : await _storage.write(key: _key, value: token);
    } catch (_) {
      // Storage failures only cost the user a new login next launch.
    }
  }
}

class MemoryRefreshTokenStore implements RefreshTokenStore {
  String? _token;
  @override
  Future<String?> read() async => _token;
  @override
  Future<void> write(String? token) async => _token = token;
}

enum SessionStatus { restoring, signedOut, signedIn }

/// Owns login state and tokens. Repositories receive its [api] client.
class AuthSession extends ChangeNotifier implements AccessTokenProvider {
  AuthSession({ApiClient? api, RefreshTokenStore? store})
    : api = api ?? ApiClient(),
      _store = store ?? SecureRefreshTokenStore() {
    this.api.tokens = this;
  }

  final ApiClient api;
  final RefreshTokenStore _store;
  SessionStatus _status = SessionStatus.restoring;
  AuthUser? _user;
  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshing;

  SessionStatus get status => _status;
  AuthUser? get user => _user;
  @override
  String? get accessToken => _accessToken;

  /// Restores a saved session at startup; never throws.
  Future<void> restore() async {
    final saved = await _store.read();
    if (saved == null) {
      _setSignedOut();
      return;
    }
    _refreshToken = saved;
    if (!await refreshAccessToken()) _setSignedOut();
  }

  Future<void> login(String email, String password) async {
    final json = await api.post(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
      auth: false,
    );
    await _accept(json);
  }

  Future<void> register(RegistrationRequest request) async {
    final json = await api.post(
      '/auth/register',
      body: request.toJson(),
      auth: false,
    );
    await _accept(json);
  }

  Future<void> logout() async {
    final token = _refreshToken;
    _clear();
    await _store.write(null);
    notifyListeners();
    if (token != null) {
      try {
        await api.post(
          '/auth/logout',
          body: {'refreshToken': token},
          auth: false,
        );
      } catch (_) {
        // The local session is gone either way; the server token expires.
      }
    }
  }

  void updateUser(AuthUser user) {
    if (_user?.id != user.id) return;
    _user = user;
    notifyListeners();
  }

  @override
  Future<bool> refreshAccessToken() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<bool> _refresh() async {
    final token = _refreshToken;
    if (token == null) return false;
    try {
      final json = await api.post(
        '/auth/refresh',
        body: {'refreshToken': token},
        auth: false,
      );
      await _accept(json);
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 400) {
        _clear();
        await _store.write(null);
      } else if (_user == null) {
        // Offline at startup: keep the saved token for the next launch.
        _refreshToken = null;
      }
      return false;
    }
  }

  @override
  void onUnauthorized() {
    if (_status != SessionStatus.signedIn) return;
    _clear();
    unawaited(_store.write(null));
    notifyListeners();
  }

  Future<void> _accept(Object? json) async {
    if (json is! Map<String, dynamic>) {
      throw const ApiException('BAD_RESPONSE', 'Sunucu yanıtı okunamadı.');
    }
    _user = AuthUser.fromJson(json['user'] as Map<String, dynamic>);
    _accessToken = json['accessToken'] as String;
    _refreshToken = json['refreshToken'] as String;
    await _store.write(_refreshToken);
    _status = SessionStatus.signedIn;
    notifyListeners();
  }

  void _clear() {
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _status = SessionStatus.signedOut;
  }

  void _setSignedOut() {
    _clear();
    notifyListeners();
  }
}
