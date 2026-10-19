import 'package:worknet/core/domain/failure.dart';

class UserSession {
  const UserSession({
    required this.token,
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.companyState,
  });
  final String token, name, email, role;
  final int id;
  final String? companyState;
  UserSession copyWith({String? name, String? token, String? role}) =>
      UserSession(
        token: token ?? this.token,
        id: id,
        name: name ?? this.name,
        email: email,
        role: role ?? this.role,
        companyState: companyState,
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
  Future<void> restore() async {
    current = await repository.restore();
    remembered = current != null;
  }

  Future<void> login(String email, String password, bool remember) async {
    final next = await repository.login(email.trim().toLowerCase(), password);
    if (remember) {
      await repository.remember(next);
    } else {
      await repository.clear();
    }
    current = next;
    remembered = remember;
  }

  Future<void> logout() async {
    final token = current?.token;
    if (token != null) {
      try {
        await repository.revoke(token);
      } on ApiFailure catch (e) {
        if (e.status != 401) rethrow;
      }
    }
    // A failed remote request never claims a confirmed remote logout.
    await repository.clear();
    current = null;
    remembered = false;
  }

  Future<void> expire() async {
    current = null;
    remembered = false;
    await repository.clear();
  }

  Future<void> update({String? name, String? token, String? role}) async {
    final previous = current;
    if (previous == null) return;
    final next = previous.copyWith(name: name, token: token, role: role);
    try {
      if (remembered) await repository.remember(next);
    } catch (_) {
      await expire();
      rethrow;
    }
    current = next;
  }
}
