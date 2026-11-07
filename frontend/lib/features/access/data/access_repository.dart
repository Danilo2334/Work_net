import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/access/domain/access.dart';

abstract interface class SessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  const SecureSessionStore();
  static const _storage = FlutterSecureStorage();
  static const _key = 'worknet.remembered_session.v1';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

abstract final class SessionModel {
  static UserSession parse(Map<String, dynamic> json) {
    final user = json['user'];
    if (json['token'] is! String ||
        (json['token'] as String).isEmpty ||
        user is! Map ||
        user['id'] is! int ||
        user['full_name'] is! String ||
        user['email'] is! String ||
        user['email_verified'] != true ||
        (user['company_state'] != null &&
            ![
              'pending',
              'approved',
              'rejected',
            ].contains(user['company_state'])) ||
        ![
          'candidato',
          'empresa',
          'admin',
          'unassigned',
        ].contains(user['role'])) {
      throw const ApiFailure('El servicio no confirmó una sesión válida.');
    }
    return UserSession(
      token: json['token'],
      id: user['id'],
      name: user['full_name'],
      email: user['email'],
      role: user['role'],
      companyState: user['company_state'] as String?,
    );
  }

  static Map<String, dynamic> encode(UserSession s) => {
    'token': s.token,
    'user': {
      'id': s.id,
      'full_name': s.name,
      'email': s.email,
      'role': s.role,
      'email_verified': true,
      'company_state': s.companyState,
    },
  };
}

class HttpAccessRepository implements AccessRepository {
  HttpAccessRepository(this.api, this.store);
  final WorkNetApi api;
  final SessionStore store;
  @override
  Future<UserSession> login(String email, String password) async =>
      SessionModel.parse(
        await api.request(
          'login/',
          data: {'email': email, 'password': password},
        ),
      );
  @override
  Future<UserSession?> restore() async {
    final value = await store.read();
    return value == null
        ? null
        : SessionModel.parse(jsonDecode(value) as Map<String, dynamic>);
  }

  @override
  Future<void> remember(UserSession s) async {
    try {
      await store.write(jsonEncode(SessionModel.encode(s)));
    } catch (_) {
      throw const ApiFailure(
        'No pudimos actualizar la sesión guardada. Vuelve a intentarlo.',
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await store.clear();
    } catch (_) {
      throw const ApiFailure(
        'No pudimos borrar la sesión guardada. Intenta cerrar sesión de nuevo.',
      );
    }
  }

  @override
  Future<void> revoke(String token) async {
    await api.request('logout/', token: token, data: {});
  }

  @override
  Future<String> chooseRole(String token, String role) async {
    final response = await api.request(
      'register/role/',
      token: token,
      data: {'role': role},
    );
    if (response['user'] is! Map || response['user']['role'] != role) {
      throw const ApiFailure('No pudimos confirmar el rol seleccionado.');
    }
    return role;
  }

  @override
  Future<void> requestRecovery(String email) async {
    await api.request(
      'password-recovery/request/',
      data: {'email': email.trim().toLowerCase()},
    );
  }

  @override
  Future<void> resetPassword(
    String uid,
    String token,
    String password,
    String confirmation,
  ) async {
    await api.request(
      'password-recovery/confirm/',
      data: {
        'uid': uid,
        'token': token,
        'new_password': password,
        'new_password_confirm': confirmation,
      },
    );
  }
}
