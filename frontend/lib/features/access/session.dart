import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api/worknet_api.dart';

class UserSession {
  const UserSession({
    required this.token,
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
  final String token;
  final int id;
  final String name;
  final String email;
  final String role;

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    if (json['token'] is! String ||
        (json['token'] as String).isEmpty ||
        user is! Map ||
        user['id'] is! int ||
        user['full_name'] is! String ||
        user['email'] is! String ||
        user['email_verified'] != true ||
        !['candidato', 'empresa', 'admin'].contains(user['role'])) {
      throw const FormatException('Sesión no válida');
    }
    return UserSession(
      token: json['token'],
      id: user['id'],
      name: user['full_name'],
      email: user['email'],
      role: user['role'],
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'user': {
      'id': id,
      'full_name': name,
      'email': email,
      'role': role,
      'email_verified': true,
    },
  };
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

class SessionController extends ChangeNotifier {
  SessionController({required this.api, required this.store});
  final WorkNetApi api;
  final SessionStore store;
  UserSession? session;
  bool restoring = true;
  String? notice;
  bool _disposed = false;

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
      final value = await store.read();
      if (value != null) {
        session = UserSession.fromJson(
          jsonDecode(value) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      session = null;
      notice =
          'No pudimos restaurar la sesión guardada. Inicia sesión de nuevo.';
      try {
        await store.clear();
      } catch (_) {
        /* A later login can replace the entry. */
      }
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
    final response = await api.request(
      'login/',
      data: {'email': email.trim().toLowerCase(), 'password': password},
    );
    UserSession next;
    try {
      next = UserSession.fromJson(response);
    } on FormatException {
      throw const ApiFailure('El servicio no confirmó una sesión válida.');
    }
    try {
      if (remember) {
        await store.write(jsonEncode(next.toJson()));
      } else {
        await store.clear();
      }
    } catch (_) {
      throw const ApiFailure(
        'No pudimos actualizar la sesión guardada. Vuelve a intentarlo.',
      );
    }
    session = next;
    notice = null;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await store.clear();
    } catch (_) {
      throw const ApiFailure(
        'No pudimos borrar la sesión guardada. Intenta cerrar sesión de nuevo.',
      );
    }
    session = null;
    notice = null;
    notifyListeners();
  }

  Future<void> expire({bool announce = true}) async {
    session = null;
    notice = announce
        ? 'Tu sesión ya no es válida. Inicia sesión de nuevo.'
        : null;
    notifyListeners();
    try {
      await store.clear();
    } catch (_) {
      /* Invalid tokens remain rejected by Django. */
    }
  }
}
