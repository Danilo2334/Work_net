enum PublicRole {
  candidate('candidato', 'Candidato'),
  company('empresa', 'Empresa');

  const PublicRole(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class RegistrationData {
  const RegistrationData({
    required this.fullName,
    required this.email,
    required this.password,
    required this.passwordConfirmation,
    this.role,
  });

  final String fullName;
  final String email;
  final String password;
  final String passwordConfirmation;
  final PublicRole? role;
}

class RegisteredUser {
  const RegisteredUser({
    required this.email,
    required this.role,
    required this.emailVerified,
    this.registrationToken,
  });

  final String email;
  final PublicRole? role;
  final bool emailVerified;
  final String? registrationToken;
}

class RegistrationFailure implements Exception {
  const RegistrationFailure(this.message, {this.fieldErrors = const {}});
  final String message;
  final Map<String, String> fieldErrors;
}

abstract interface class RegistrationRepository {
  Future<RegisteredUser> register(RegistrationData data);
  Future<RegisteredUser> chooseRole(RegisteredUser user, PublicRole role);
}

class CreateAccount {
  const CreateAccount(this.repository);
  final RegistrationRepository repository;
  Future<RegisteredUser> call(RegistrationData data) async {
    final errors = <String, String?>{
      'full_name': RegistrationValidation.fullName(data.fullName),
      'email': RegistrationValidation.email(data.email),
      'password': RegistrationValidation.password(data.password),
      'password_confirm': RegistrationValidation.confirmation(
        data.passwordConfirmation,
        data.password,
      ),
    }..removeWhere((_, v) => v == null);
    if (errors.isNotEmpty) {
      throw RegistrationFailure(
        'Revisa tus datos.',
        fieldErrors: errors.cast<String, String>(),
      );
    }
    return repository.register(data);
  }
}

abstract final class RegistrationValidation {
  static String? fullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Escribe tu nombre completo.';
    if (name.length > 150) return 'Usa máximo 150 caracteres.';
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Escribe tu correo electrónico.';
    if (email.length > 254 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Escribe un correo electrónico válido.';
    }
    return null;
  }

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Escribe una contraseña.';
    if (password.length < 8) return 'Usa al menos 8 caracteres.';
    if (password.trim() != password) {
      return 'Evita espacios al principio o al final de la contraseña.';
    }
    if (RegExp(r'^\d+$').hasMatch(password)) {
      return 'La contraseña no puede contener solamente números.';
    }
    return null;
  }

  static String? confirmation(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirma tu contraseña.';
    if (value != password) return 'Las contraseñas no coinciden.';
    return null;
  }
}
