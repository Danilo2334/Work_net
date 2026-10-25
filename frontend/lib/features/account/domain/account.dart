import 'package:worknet/features/access/domain/access.dart';

class AccountInfo {
  const AccountInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.verified,
  });
  final int id;
  final String name, email, role;
  final bool verified;
}

class AccountSettings {
  const AccountSettings(this.user, this.push);
  final AccountInfo user;
  final bool push;
}

abstract interface class AccountRepository {
  Future<AccountSettings> load(UserSession session);
  Future<AccountInfo> rename(UserSession session, String name);
  Future<String> changePassword(
    String token,
    String current,
    String password,
    String confirmation,
  );
  Future<bool> setPush(String token, bool value);
  Future<void> delete(String token, String password);
}
