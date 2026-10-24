import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/access/domain/access.dart';
import 'package:worknet/features/account/domain/account.dart';

class HttpAccountRepository implements AccountRepository {
  HttpAccountRepository(this.api);
  final WorkNetApi api;
  AccountInfo _user(Map<String, dynamic> response, UserSession session) {
    final u = response['user'];
    if (u is! Map ||
        u['id'] != session.id ||
        u['full_name'] is! String ||
        u['email'] is! String ||
        u['role'] != session.role ||
        u['email_verified'] is! bool) {
      throw const ApiFailure('No pudimos interpretar los datos de la cuenta.');
    }
    return AccountInfo(
      id: u['id'],
      name: u['full_name'],
      email: u['email'],
      role: u['role'],
      verified: u['email_verified'],
    );
  }

  bool _push(Map<String, dynamic> r) {
    final p = r['preferences'];
    if (p is! Map || p['push_notifications'] is! bool) {
      throw const ApiFailure('No pudimos interpretar las preferencias.');
    }
    return p['push_notifications'];
  }

  @override
  Future<AccountSettings> load(UserSession s) async {
    final rows = await Future.wait([
      api.request('account/', token: s.token),
      api.request('account/notifications/', token: s.token),
    ]);
    return AccountSettings(_user(rows[0], s), _push(rows[1]));
  }

  @override
  Future<AccountInfo> rename(UserSession s, String name) async => _user(
    await api.request(
      'account/',
      token: s.token,
      method: 'PATCH',
      data: {'full_name': name.trim()},
    ),
    s,
  );
  @override
  Future<String> changePassword(
    String token,
    String current,
    String password,
    String confirmation,
  ) async {
    final r = await api.request(
      'account/password/',
      token: token,
      data: {
        'current_password': current,
        'new_password': password,
        'new_password_confirm': confirmation,
      },
    );
    if (r['token'] is! String || (r['token'] as String).isEmpty) {
      throw const ApiFailure(
        'El servicio no confirmó la nueva sesión. Inicia sesión de nuevo.',
        status: 401,
      );
    }
    return r['token'];
  }

  @override
  Future<bool> setPush(String token, bool value) async => _push(
    await api.request(
      'account/notifications/',
      token: token,
      method: 'PATCH',
      data: {'push_notifications': value},
    ),
  );
  @override
  Future<void> delete(String token, String password) async {
    await api.request(
      'account/delete/',
      token: token,
      method: 'DELETE',
      data: {'current_password': password, 'confirmation': true},
    );
  }
}
