import 'package:worknet/core/domain/failure.dart';

import 'access.dart';

class MfaRequired extends ApiFailure {
  MfaRequired(this.challenge, this.enrollment, this.expiresAt)
    : super('Confirma el segundo factor para continuar.');
  final String challenge;
  final bool enrollment;
  final DateTime expiresAt;
}

class MfaSetup {
  const MfaSetup(this.secret);
  final String secret;
}

class MfaResult {
  const MfaResult(this.session, this.recoveryCodes);
  final UserSession session;
  final List<String> recoveryCodes;
}

abstract interface class AdminMfaRepository {
  Future<MfaSetup> setupMfa(String challenge);
  Future<MfaResult> verifyMfa(
    String challenge,
    String code, {
    bool recovery = false,
  });
}
