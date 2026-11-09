import 'package:worknet/core/domain/failure.dart';

class UserSession {
  const UserSession({
    required this.token,
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.companyState,
    this.administrativeRole,
    this.permissions = const [],
  });
  final String token, name, email, role;
  final int id;
  final String? companyState;
  final String? administrativeRole;
  final List<String> permissions;
  bool can(String permission) =>
      role == 'admin' && permissions.contains(permission);
  UserSession copyWith({String? name, String? token, String? role}) =>
      UserSession(
        token: token ?? this.token,
        id: id,
        name: name ?? this.name,
        email: email,
        role: role ?? this.role,
        companyState: companyState,
        administrativeRole: administrativeRole,
        permissions: permissions,
      );
}

abstract interface class AccessRepository {
  Future<UserSession> login(String email, String password);
  Future<UserSession?> restore();
  Future<void> remember(UserSession session);
  Future<void> clear();
  Future<void> revoke(String token);
  Future<String> chooseRole(String token, String role);
  Future<void> requestRecovery(String email);
  Future<void> resetPassword(
    String uid,
    String token,
    String password,
    String confirmation,
  );
}

/// Session policy independent of Flutter, HTTP and the storage implementation.
class SessionLifecycle {
  SessionLifecycle(this.repository);
  final AccessRepository repository;
  UserSession? current;
  bool remembered = false;
  int _epoch = 0;
  Future<void> _storageTail = Future<void>.value();
  Future<void> _store(Future<void> Function() action) {
    final next = _storageTail.then((_) => action());
    _storageTail = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<void> restore() async {
    final operation = ++_epoch;
    final restored = await repository.restore();
    if (operation != _epoch) return;
    current = restored;
    remembered = current != null;
  }

  Future<void> login(String email, String password, bool remember) async {
    final operation = ++_epoch;
    final next = await repository.login(email.trim().toLowerCase(), password);
    await accept(next, remember, operation: operation);
  }

  Future<void> accept(UserSession next, bool remember, {int? operation}) async {
    final epoch = operation ?? ++_epoch;
    if (epoch != _epoch) return;
    await _store(() async {
      if (epoch != _epoch) return;
      if (remember) {
        await repository.remember(next);
      } else {
        await repository.clear();
      }
    });
    if (epoch != _epoch) return;
    current = next;
    remembered = remember;
  }

  Future<void> logout() async {
    final operation = ++_epoch;
    final token = current?.token;
    if (token != null) {
      try {
        await repository.revoke(token);
      } on ApiFailure catch (e) {
        if (e.status != 401) rethrow;
      }
    }
    // A failed remote request never claims a confirmed remote logout.
    if (operation != _epoch) return;
    await _store(() async {
      if (operation == _epoch) await repository.clear();
    });
    if (operation != _epoch) return;
    current = null;
    remembered = false;
  }

  Future<void> expire() async {
    ++_epoch;
    current = null;
    remembered = false;
    // Expiration is already confirmed. A later password attempt (including MFA202
    // or failure) must not cancel this erase. Any accepted new session is queued after it.
    await _store(repository.clear);
  }

  Future<void> update({String? name, String? token, String? role}) async {
    final previous = current;
    if (previous == null) return;
    final operation = ++_epoch;
    final next = previous.copyWith(name: name, token: token, role: role);
    try {
      if (remembered) {
        await _store(() async {
          if (operation == _epoch) await repository.remember(next);
        });
      }
    } catch (_) {
      if (operation == _epoch) await expire();
      rethrow;
    }
    if (operation != _epoch) return;
    current = next;
  }
}
