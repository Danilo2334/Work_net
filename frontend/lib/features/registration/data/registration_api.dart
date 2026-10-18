import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/registration.dart';

class RegistrationFailure implements Exception {
  const RegistrationFailure(this.message, {this.fieldErrors = const {}});

  final String message;
  final Map<String, String> fieldErrors;
}

class RegistrationApi {
  RegistrationApi({http.Client? client, Uri? baseUri, this.timeout})
    : _client = client ?? http.Client(),
      _baseUri = baseUri ?? _configuredBaseUri();

  final http.Client _client;
  final Uri _baseUri;
  final Duration? timeout;

  static Uri _configuredBaseUri() {
    const url = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8000/api/',
    );
    return Uri.parse(url.endsWith('/') ? url : '$url/');
  }

  Future<RegisteredUser> register(RegistrationData data) async {
    http.Response response;
    try {
      response = await _client
          .post(
            _baseUri.resolve('register/'),
            headers: const {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(data.toJson()),
          )
          .timeout(timeout ?? const Duration(seconds: 20));
    } on TimeoutException {
      throw const RegistrationFailure(
        'No pudimos confirmar el registro a tiempo. '
        'Revisa tu correo antes de volver a intentarlo.',
      );
    } on http.ClientException {
      throw const RegistrationFailure(
        'No pudimos conectarnos. Comprueba tu conexión y vuelve a intentarlo.',
      );
    }

    if (response.statusCode >= 500) {
      throw const RegistrationFailure(
        'No pudimos confirmar el registro. Revisa tu correo antes de '
        'volver a intentarlo en unos minutos.',
      );
    }

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      body = decoded;
    } on FormatException {
      throw const RegistrationFailure(
        'No pudimos confirmar el registro. Revisa tu correo antes de '
        'volver a intentarlo.',
      );
    }

    if (response.statusCode != 201) {
      final errors = <String, String>{};
      final raw = body['errors'];
      if (raw is Map) {
        for (final entry in raw.entries) {
          final value = entry.value;
          if (value is List) {
            errors[entry.key.toString()] = value.join('\n');
          } else if (value is String) {
            errors[entry.key.toString()] = value;
          }
        }
      }
      final message =
          errors['non_field_errors'] ??
          (body['message'] is String
              ? body['message'] as String
              : 'No pudimos crear tu cuenta. Vuelve a intentarlo.');
      throw RegistrationFailure(message, fieldErrors: errors);
    }

    final user = body['user'];
    if (user is! Map<String, dynamic> ||
        user['email'] is! String ||
        user['email_verified'] is! bool ||
        user['role'] != data.role.apiValue) {
      throw const RegistrationFailure(
        'No pudimos confirmar el registro. Revisa tu correo antes de '
        'volver a intentarlo.',
      );
    }
    return RegisteredUser(
      email: user['email'] as String,
      role: data.role,
      emailVerified: user['email_verified'] as bool,
    );
  }

  void close() => _client.close();
}
