import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/access/domain/access.dart';
import 'package:worknet/features/access/domain/admin_mfa.dart';

const adminPermissionKeys = {
  'dashboard',
  'review_companies',
  'view_events',
  'manage_admins',
  'manage_permissions',
};

MfaRequired? parseMfa(Map<String, dynamic> json) {
  if (json['mfa_required'] != true) return null;
  final expires = DateTime.tryParse(json['expires_at']?.toString() ?? '');
  if (json.containsKey('token') ||
      json['challenge'] is! String ||
      !RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      ).hasMatch(json['challenge']) ||
      json['enrollment_required'] is! bool ||
      expires == null) {
    throw const ApiFailure(
      'El servicio no confirmó un desafío de doble factor válido.',
    );
  }
  return MfaRequired(json['challenge'], json['enrollment_required'], expires);
}

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
    if (user['role'] == 'admin' &&
        (user['mfa_verified'] != true ||
            ![
              'principal',
              'gestor',
              'revisor',
            ].contains(user['administrative_role']) ||
            user['permissions'] is! List ||
            (user['permissions'] as List).any(
              (p) => !adminPermissionKeys.contains(p),
            ))) {
      throw const ApiFailure(
        'La sesión administrativa requiere doble factor y permisos confirmados.',
      );
    }
    return UserSession(
      token: json['token'],
      id: user['id'],
      name: user['full_name'],
      email: user['email'],
      role: user['role'],
      companyState: user['company_state'] as String?,
      administrativeRole: user['administrative_role'] as String?,
      permissions: user['role'] == 'admin'
          ? List<String>.unmodifiable(user['permissions'])
          : const [],
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
      if (s.role == 'admin') ...{
        'mfa_verified': true,
        'administrative_role': s.administrativeRole,
        'permissions': s.permissions,
      },
    },
  };
}

class HttpAccessRepository implements AccessRepository, AdminMfaRepository {
  HttpAccessRepository(this.api, this.store);
  final WorkNetApi api;
  final SessionStore store;
  @override
  Future<UserSession> login(String email, String password) async {
    final response = await api.request(
      'login/',
      data: {'email': email, 'password': password},
    );
    final mfa = parseMfa(response);
    if (mfa != null) throw mfa;
    return SessionModel.parse(response);
  }

  @override
  Future<MfaSetup> setupMfa(String challenge) async {
    final response = await api.request(
      'admin/mfa/setup/',
      data: {'challenge': challenge},
    );
    final secret = response['secret'];
    if (secret is! String || !RegExp(r'^[A-Z2-7]{32}$').hasMatch(secret)) {
      throw const ApiFailure(
        'El servicio no confirmó una clave de autenticador válida.',
      );
    }
    return MfaSetup(secret);
  }

  @override
  Future<MfaResult> verifyMfa(
    String challenge,
    String code, {
    bool recovery = false,
  }) async {
    final response = await api.request(
      'admin/mfa/verify/',
      data: {'challenge': challenge, 'code': code, 'recovery': recovery},
    );
    final next = parseMfa(response);
    if (next != null) throw next;
    final codes = response['recovery_codes'] ?? <String>[];
    if (codes is! List ||
        codes.any(
          (c) => c is! String || !RegExp(r'^[0-9a-f]{32}$').hasMatch(c),
        )) {
      throw const ApiFailure(
        'No pudimos interpretar los códigos de recuperación.',
      );
    }
    return MfaResult(
      SessionModel.parse(response),
      List<String>.unmodifiable(codes),
    );
  }

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
