import '../../../core/api/api_client.dart';
import 'password_reset_repository.dart';

/// `/auth/forgot-password` + `/auth/reset-password`.
///
/// The backend checks the code together with the new password in one call,
/// so [verifyCode] only checks the format and the server decides at the end.
class RemotePasswordResetRepository implements PasswordResetRepository {
  RemotePasswordResetRepository(this.api);
  final ApiClient api;
  final Map<String, String> _emailByGrant = {};

  @override
  Future<ResetChallenge> requestCode(String email) async {
    try {
      await api.post(
        '/auth/forgot-password',
        body: {'email': email.trim()},
        auth: false,
      );
    } on ApiException catch (error) {
      if (error.code == 'RATE_LIMITED') throw ResetCodeFailure.tooManyAttempts;
      throw const ResetUnavailable();
    }
    final now = DateTime.now();
    return ResetChallenge(
      id: email.trim().toLowerCase(),
      email: email.trim(),
      resendAvailableAt: now.add(const Duration(seconds: 60)),
    );
  }

  @override
  Future<ResetChallenge> resendCode(ResetChallenge challenge) =>
      requestCode(challenge.email);

  @override
  Future<ResetGrant> verifyCode(ResetChallenge challenge, String code) async {
    final trimmed = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      throw ResetCodeFailure.invalidCode;
    }
    final grant = ResetGrant(token: trimmed);
    _emailByGrant[trimmed] = challenge.email;
    return grant;
  }

  @override
  Future<void> updatePassword(ResetGrant grant, String password) async {
    final email = _emailByGrant[grant.token];
    if (email == null) throw ResetGrantFailure.invalidGrant;
    try {
      await api.post(
        '/auth/reset-password',
        body: {'email': email, 'code': grant.token, 'newPassword': password},
        auth: false,
      );
      _emailByGrant.remove(grant.token);
    } on ApiException catch (error) {
      throw switch (error.code) {
        'INVALID_CODE' => ResetGrantFailure.invalidGrant,
        'EXPIRED' ||
        'LOCKED' ||
        'RATE_LIMITED' => ResetGrantFailure.expiredGrant,
        _ => const ResetUnavailable(),
      };
    }
  }
}
