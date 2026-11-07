import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/features/registration/data/registration_api.dart';
import 'package:worknet/features/registration/domain/registration.dart';

const data = RegistrationData(
  fullName: '  Persona de prueba  ',
  email: '  PRUEBA@example.com  ',
  password: 'RegistroSeguro!2026',
  passwordConfirmation: 'RegistroSeguro!2026',
  role: PublicRole.candidate,
);

http.Response created({String role = 'candidato'}) => http.Response(
  jsonEncode({
    'message': 'Usuario registrado correctamente.',
    'user': {
      'id': 12,
      'full_name': 'Persona de prueba',
      'email': 'prueba@example.com',
      'role': role,
      'email_verified': false,
    },
  }),
  201,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('envía los nombres de campos y el rol esperados por Django', () async {
    final api = RegistrationApi(
      baseUri: Uri.parse('https://worknet.example/api/'),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'https://worknet.example/api/register/');
        expect(request.headers['Content-Type'], contains('application/json'));
        expect(jsonDecode(request.body), {
          'full_name': 'Persona de prueba',
          'email': 'prueba@example.com',
          'password': 'RegistroSeguro!2026',
          'password_confirm': 'RegistroSeguro!2026',
          'role': 'candidato',
        });
        expect(request.headers.containsKey('Authorization'), false);
        return created();
      }),
    );
    addTearDown(api.close);
    final user = await api.register(data);
    expect(user.email, 'prueba@example.com');
    expect(user.role, PublicRole.candidate);
    expect(user.emailVerified, false);
  });

  test('conserva el rol empresa confirmado por el servidor', () async {
    final api = RegistrationApi(
      client: MockClient((request) async {
        expect(jsonDecode(request.body)['role'], 'empresa');
        return created(role: 'empresa');
      }),
    );
    addTearDown(api.close);
    final user = await api.register(
      const RegistrationData(
        fullName: 'Representante',
        email: 'empresa@example.com',
        password: 'RegistroSeguro!2026',
        passwordConfirmation: 'RegistroSeguro!2026',
        role: PublicRole.company,
      ),
    );
    expect(user.role, PublicRole.company);
  });

  test(
    'propaga correo duplicado y validación de contraseña por campo',
    () async {
      final api = RegistrationApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'message': 'No fue posible registrar el usuario.',
              'errors': {
                'email': ['Este correo ya está registrado.'],
                'password': ['La contraseña es demasiado común.'],
              },
            }),
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.register(data),
        throwsA(
          isA<RegistrationFailure>()
              .having(
                (e) => e.fieldErrors['email'],
                'email',
                contains('registrado'),
              )
              .having(
                (e) => e.fieldErrors['password'],
                'password',
                contains('común'),
              ),
        ),
      );
    },
  );

  test('muestra las validaciones generales de Django', () async {
    final api = RegistrationApi(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'errors': {
              'non_field_errors': ['La contraseña es demasiado común.'],
            },
          }),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.register(data),
      throwsA(
        isA<RegistrationFailure>().having(
          (e) => e.message,
          'message',
          'La contraseña es demasiado común.',
        ),
      ),
    );
  });

  test('no expone HTML ni detalles internos de un error 500', () async {
    final api = RegistrationApi(
      client: MockClient(
        (_) async => http.Response('Traceback: SMTP_SECRET', 500),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.register(data),
      throwsA(
        isA<RegistrationFailure>().having(
          (e) => e.message,
          'message',
          allOf(contains('Revisa tu correo'), isNot(contains('SMTP_SECRET'))),
        ),
      ),
    );
  });

  test('un 200 o una respuesta 201 inválida no anuncia éxito', () async {
    for (final response in [
      http.Response('{}', 200),
      http.Response('[]', 201),
      http.Response('not-json', 201),
      created(role: 'admin'),
      http.Response('{"user":{"email":"prueba@example.com"}}', 201),
    ]) {
      final api = RegistrationApi(client: MockClient((_) async => response));
      addTearDown(api.close);
      await expectLater(
        api.register(data),
        throwsA(isA<RegistrationFailure>()),
      );
    }
  });

  test(
    'informa pérdida de conexión sin confundirla con un registro exitoso',
    () async {
      final api = RegistrationApi(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(api.close);
      await expectLater(
        api.register(data),
        throwsA(
          isA<RegistrationFailure>().having(
            (e) => e.message,
            'message',
            contains('conectarnos'),
          ),
        ),
      );
    },
  );

  test('un timeout advierte comprobar el correo antes de repetir', () async {
    final pending = Completer<http.Response>();
    final api = RegistrationApi(
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => pending.future),
    );
    addTearDown(api.close);
    await expectLater(
      api.register(data),
      throwsA(
        isA<RegistrationFailure>().having(
          (e) => e.message,
          'message',
          contains('Revisa tu correo'),
        ),
      ),
    );
    pending.complete(created());
  });

  test('validación local cubre obligatorios y coincidencia exacta', () {
    expect(RegistrationValidation.fullName('  '), isNotNull);
    expect(RegistrationValidation.fullName('Ana Pérez'), isNull);
    expect(RegistrationValidation.email('incorrecto@'), isNotNull);
    expect(RegistrationValidation.email('ana@example.com'), isNull);
    expect(RegistrationValidation.password('12345678'), isNotNull);
    expect(RegistrationValidation.password('corta'), isNotNull);
    expect(RegistrationValidation.password(' Secreto!2026'), isNotNull);
    expect(RegistrationValidation.password('Secreto!2026'), isNull);
    expect(
      RegistrationValidation.confirmation('Secreto!2026 ', 'Secreto!2026'),
      isNotNull,
    );
    expect(
      RegistrationValidation.confirmation('Secreto!2026', 'Secreto!2026'),
      isNull,
    );
  });
}
