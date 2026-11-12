/// API transport boundary. Only the server may issue challenges and grants.
abstract interface class PasswordResetRepository {
  Future<ResetChallenge> requestCode(String email);
  Future<ResetGrant> verifyCode(ResetChallenge challenge, String code);
  Future<ResetChallenge> resendCode(ResetChallenge challenge);
  Future<void> updatePassword(ResetGrant grant, String password);
}

class ResetChallenge {
  const ResetChallenge({
    required this.id,
    required this.email,
    this.expiresAt,
    this.resendAvailableAt,
  });
  final String id;
  final String email;
  // Optional absolute instants from the service; null means timing is unknown.
  // The client must not infer code validity from its local clock.
  final DateTime? expiresAt;
  final DateTime? resendAvailableAt;
}

// Typed service outcomes; a future API adapter maps server responses to these.
enum ResetCodeFailure implements Exception {
  invalidCode,
  expiredCode,
  tooManyAttempts,
}

// Typed grant failures, independent of future HTTP status codes or JSON fields.
enum ResetGrantFailure implements Exception { invalidGrant, expiredGrant }

class ResetGrant {
  const ResetGrant({required this.token});
  final String token;
}

class ResetUnavailable implements Exception {
  const ResetUnavailable();
  static const message =
      'Şifre sıfırlama hizmeti henüz kullanılamıyor. E-posta gönderilmedi, kod doğrulanmadı ve şifre değiştirilmedi.';
}

/// No network requests or fabricated success while the API is unavailable.
class UnavailablePasswordResetRepository implements PasswordResetRepository {
  const UnavailablePasswordResetRepository();
  @override
  Future<ResetChallenge> requestCode(String email) async =>
      throw const ResetUnavailable();
  @override
  Future<ResetGrant> verifyCode(ResetChallenge challenge, String code) async =>
      throw const ResetUnavailable();
  @override
  Future<ResetChallenge> resendCode(ResetChallenge challenge) async =>
      throw const ResetUnavailable();
  @override
  Future<void> updatePassword(ResetGrant grant, String password) async =>
      throw const ResetUnavailable();
}
