import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/app.dart';
import 'package:worknet/features/registration/data/registration_api.dart';

http.Response success(String role) => http.Response(
  jsonEncode({
    'user': {
      'email': 'persona@example.com',
      'role': role,
      'email_verified': false,
    },
  }),
  201,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> fillDetails(WidgetTester tester) async {
  for (final entry in {
    'full_name': 'Persona de prueba',
    'email': 'persona@example.com',
    'password': 'RegistroSeguro!2026',
    'password_confirm': 'RegistroSeguro!2026',
  }.entries) {
    await tester.enterText(find.byKey(Key(entry.key)), entry.value);
  }
  await tapVisible(tester, find.byKey(const Key('continue_registration')));
}

Future<void> start(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
  final api = RegistrationApi(client: MockClient(handler));
  addTearDown(api.close);
  await tester.pumpWidget(WorkNetApp(registrationApi: api));
}

void main() {
  testWidgets('los campos vacíos bloquean avanzar y no hacen peticiones', (
    tester,
  ) async {
    var calls = 0;
    await start(tester, (_) async {
      calls++;
      return success('candidato');
    });
    await tapVisible(tester, find.byKey(const Key('continue_registration')));
    expect(find.text('Escribe tu nombre completo.'), findsOneWidget);
    expect(find.text('Escribe tu correo electrónico.'), findsOneWidget);
    expect(find.text('Escribe una contraseña.'), findsOneWidget);
    expect(find.text('Confirma tu contraseña.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('las contraseñas deben coincidir antes de elegir rol', (
    tester,
  ) async {
    await start(tester, (_) async => success('candidato'));
    await tester.enterText(find.byKey(const Key('full_name')), 'Persona');
    await tester.enterText(
      find.byKey(const Key('email')),
      'persona@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('password')),
      'RegistroSeguro!2026',
    );
    await tester.enterText(
      find.byKey(const Key('password_confirm')),
      'OtraClave!2026',
    );
    await tapVisible(tester, find.byKey(const Key('continue_registration')));
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(find.byKey(const Key('role_candidato')), findsNothing);
  });

  testWidgets('solo ofrece candidato y empresa; exige elegir uno', (
    tester,
  ) async {
    await start(tester, (_) async => success('candidato'));
    await fillDetails(tester);
    expect(find.text('Candidato'), findsOneWidget);
    expect(find.text('Empresa'), findsOneWidget);
    expect(find.textContaining('Administrador'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('submit_registration')))
          .onPressed,
      isNull,
    );
    await tapVisible(tester, find.byKey(const Key('role_candidato')));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('submit_registration')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('volver desde rol conserva los datos escritos', (tester) async {
    await start(tester, (_) async => success('candidato'));
    await fillDetails(tester);
    await tapVisible(tester, find.byKey(const Key('edit_registration')));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('full_name')))
          .controller!
          .text,
      'Persona de prueba',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('email')))
          .controller!
          .text,
      'persona@example.com',
    );
  });

  for (final role in ['candidato', 'empresa']) {
    testWidgets('registra $role y confirma el correo solo después del 201', (
      tester,
    ) async {
      await start(tester, (request) async {
        expect(jsonDecode(request.body)['role'], role);
        return success(role);
      });
      await fillDetails(tester);
      await tapVisible(tester, find.byKey(Key('role_$role')));
      await tapVisible(tester, find.byKey(const Key('submit_registration')));
      expect(find.text('Revisa tu correo'), findsOneWidget);
      expect(find.text('persona@example.com'), findsOneWidget);
      if (role == 'empresa') {
        expect(find.textContaining('solicitar su validación'), findsOneWidget);
      }
      await tapVisible(tester, find.byKey(const Key('new_registration')));
      for (final id in ['password', 'password_confirm']) {
        expect(
          tester.widget<TextFormField>(find.byKey(Key(id))).controller!.text,
          isEmpty,
        );
      }
    });
  }

  testWidgets('correo duplicado vuelve al formulario y permite corregirlo', (
    tester,
  ) async {
    await start(
      tester,
      (_) async => http.Response(
        jsonEncode({
          'message': 'No fue posible registrar el usuario.',
          'errors': {
            'email': ['Este correo ya está registrado.'],
          },
        }),
        400,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await fillDetails(tester);
    await tapVisible(tester, find.byKey(const Key('role_candidato')));
    await tapVisible(tester, find.byKey(const Key('submit_registration')));
    expect(find.byKey(const Key('email')), findsOneWidget);
    expect(find.text('Este correo ya está registrado.'), findsOneWidget);
    expect(find.text('Revisa tu correo'), findsNothing);
    await tester.enterText(find.byKey(const Key('email')), 'nuevo@example.com');
    await tester.pumpAndSettle();
    expect(find.text('Este correo ya está registrado.'), findsNothing);
  });

  testWidgets('una petición en curso bloquea repetir y editar el registro', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    await start(tester, (_) {
      calls++;
      return pending.future;
    });
    await fillDetails(tester);
    await tapVisible(tester, find.byKey(const Key('role_candidato')));
    final submit = find.byKey(const Key('submit_registration'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('edit_registration')))
          .onPressed,
      isNull,
    );
    await tester.tap(submit);
    await tester.pump();
    expect(calls, 1);
    pending.complete(success('candidato'));
    await tester.pumpAndSettle();
    expect(find.text('Revisa tu correo'), findsOneWidget);
  });

  testWidgets('un error de red permite reintentar conservando el rol', (
    tester,
  ) async {
    var calls = 0;
    await start(tester, (_) async {
      calls++;
      if (calls == 1) throw http.ClientException('offline');
      return success('candidato');
    });
    await fillDetails(tester);
    await tapVisible(tester, find.byKey(const Key('role_candidato')));
    await tapVisible(tester, find.byKey(const Key('submit_registration')));
    expect(find.textContaining('No pudimos conectarnos'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('submit_registration')));
    expect(calls, 2);
    expect(find.text('Revisa tu correo'), findsOneWidget);
  });

  for (final size in [
    const Size(360, 780),
    const Size(390, 844),
    const Size(1440, 960),
  ]) {
    testWidgets('formulario, roles y confirmación sin desbordes a $size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await start(tester, (_) async => success('candidato'));
      expect(tester.takeException(), isNull);
      await fillDetails(tester);
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.byKey(const Key('role_candidato')));
      await tapVisible(tester, find.byKey(const Key('submit_registration')));
      expect(tester.takeException(), isNull);
      expect(find.text('Revisa tu correo'), findsOneWidget);
    });
  }
}
