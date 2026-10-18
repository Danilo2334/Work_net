import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status, this.fields = const {}});
  final String message;
  final int? status;
  final Map<String, String> fields;
}

class WorkNetApi {
  WorkNetApi({
    http.Client? client,
    Uri? baseUri,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _base = baseUri ?? configuredBase();

  final http.Client _client;
  final Uri _base;
  final Duration timeout;

  static Uri configuredBase() {
    const value = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8000/api/',
    );
    return Uri.parse(value.endsWith('/') ? value : '$value/');
  }

  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? data,
    String? token,
    String? method,
  }) async {
    http.Response response;
    final headers = <String, String>{
      'Accept': 'application/json',
      if (data != null) 'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Token $token',
    };
    try {
      final uri = _base.resolve(path);
      final body = data == null ? null : jsonEncode(data);
      response = await (switch (method ?? (data == null ? 'GET' : 'POST')) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(uri, headers: headers, body: body),
        'PATCH' => _client.patch(uri, headers: headers, body: body),
        'DELETE' => _client.delete(uri, headers: headers, body: body),
        _ => throw ArgumentError.value(method, 'method'),
      }).timeout(timeout);
    } on TimeoutException {
      throw const ApiFailure(
        'La solicitud tardó demasiado. Comprueba tu conexión y vuelve a intentarlo.',
      );
    } on http.ClientException {
      throw const ApiFailure(
        'No pudimos conectarnos. Comprueba tu conexión y vuelve a intentarlo.',
      );
    }
    return _decode(response, path);
  }

  Future<Map<String, dynamic>> uploadProfilePhoto(
    Uint8List bytes,
    String filename, {
    required String token,
  }) async {
    final request =
        http.MultipartRequest('PUT', _base.resolve('profile/candidate/photo/'))
          ..headers['Authorization'] = 'Token $token'
          ..files.add(
            http.MultipartFile.fromBytes(
              'photo',
              bytes,
              filename: filename,
              contentType: MediaType(
                'image',
                filename.toLowerCase().endsWith('.png') ? 'png' : 'jpeg',
              ),
            ),
          );
    final response = await _transport(
      () async => http.Response.fromStream(await _client.send(request)),
    );
    return _decode(response, 'profile/candidate/photo/');
  }

  Future<Uint8List> profilePhoto({required String token}) async {
    final response = await _transport(
      () => _client.get(
        _base.resolve('profile/candidate/photo/'),
        headers: {
          'Authorization': 'Token $token',
          'Accept': 'image/jpeg, application/json',
        },
      ),
    );
    if (response.statusCode != 200) {
      _decode(response, 'profile/candidate/photo/');
    }
    if (![
      'image/jpeg',
      'image/png',
    ].contains(response.headers['content-type']?.split(';').first)) {
      throw const ApiFailure('No pudimos interpretar la fotografía.');
    }
    return response.bodyBytes;
  }

  Future<http.Response> _transport(
    Future<http.Response> Function() action,
  ) async {
    try {
      return await action().timeout(timeout);
    } on TimeoutException {
      throw const ApiFailure(
        'La solicitud tardó demasiado. Vuelve a intentarlo.',
      );
    } on http.ClientException {
      throw const ApiFailure(
        'No pudimos conectarnos. Comprueba tu conexión y vuelve a intentarlo.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response, String path) {
    if (response.statusCode >= 500) {
      throw ApiFailure(
        path.startsWith('password-recovery/request')
            ? 'No pudimos enviar el enlace de recuperación. Inténtalo de nuevo más tarde.'
            : 'El servicio no está disponible. Inténtalo de nuevo más tarde.',
        status: response.statusCode,
      );
    }
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      body = decoded;
    } on FormatException {
      throw ApiFailure(
        'Recibimos una respuesta no válida del servicio.',
        status: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final fields = <String, String>{};
      final errors = body['errors'];
      if (errors is Map) {
        for (final entry in errors.entries) {
          if (entry.value is List) {
            fields[entry.key.toString()] = (entry.value as List).join('\n');
          } else if (entry.value is String) {
            fields[entry.key.toString()] = entry.value as String;
          }
        }
      }
      throw ApiFailure(
        response.statusCode == 401
            ? 'Tu sesión ya no es válida. Inicia sesión de nuevo.'
            : fields['non_field_errors'] ??
                  fields['token'] ??
                  (body['message'] as String? ??
                      body['detail'] as String? ??
                      'No pudimos completar la solicitud.'),
        status: response.statusCode,
        fields: fields,
      );
    }
    return body;
  }

  void close() => _client.close();
}
