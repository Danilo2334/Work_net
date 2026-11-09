import 'package:flutter/foundation.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/features/access/domain/access.dart';
import 'package:worknet/features/access/domain/admin_mfa.dart';
export 'package:worknet/features/access/domain/access.dart' show UserSession;

class SessionController extends ChangeNotifier {
  SessionController({required AccessRepository repository})
    : _lifecycle = SessionLifecycle(repository);
  final SessionLifecycle _lifecycle;
  UserSession? get session => _lifecycle.current;
  bool restoring = true;
  String? notice;
  bool _disposed = false;
  AdminMfaRepository? get mfa => _lifecycle.repository is AdminMfaRepository
      ? _lifecycle.repository as AdminMfaRepository
      : null;

  Future<void> completeMfa(UserSession next, {required bool remember}) async {
    await _lifecycle.accept(next, remember);
    notice = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> restore() async {
    try {
      await _lifecycle.restore();
    } catch (_) {
      try {
        await _lifecycle.expire();
      } catch (_) {}
      notice =
          'No pudimos restaurar la sesión guardada. Inicia sesión de nuevo.';
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<void> login(
    String email,
    String password, {
    required bool remember,
  }) async {
    await _lifecycle.login(email, password, remember);
    notice = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await _lifecycle.logout();
    notice = null;
    notifyListeners();
  }

  Future<void> expire({bool announce = true}) async {
    final clearing = _lifecycle.expire();
    notice = announce
        ? 'Tu sesión ya no es válida. Inicia sesión de nuevo.'
        : null;
    notifyListeners();
    try {
      await clearing;
    } catch (_) {}
  }

  Future<void> update({String? name, String? token, String? role}) async {
    try {
      await _lifecycle.update(name: name, token: token, role: role);
    } catch (_) {
      notifyListeners();
      throw const ApiFailure(
        'El cambio se guardó, pero no pudimos actualizar la sesión. Inicia sesión de nuevo.',
      );
    }
    notifyListeners();
  }
}
