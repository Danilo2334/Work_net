import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/app.dart';
import 'package:worknet/features/registration/data/registration_api.dart';
import 'support/access_fakes.dart';

http.Response created() => jsonResponse({
  'registration_token': 'ticket-qa',
  'user': {'email': 'persona@example.com', 'role': '', 'email_verified': false},
}, 201);
http.Response selected(String role) => jsonResponse({
  'user': {
    'email': 'persona@example.com',
    'role': role,
    'email_verified': false,
  },
});
Future<void> tapVisible(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> details(WidgetTester t) async {
  for (final e in {
    'full_name': 'Persona QA',
    'email': 'persona@example.com',
    'password': 'RegistroSeguro!2026',
    'password_confirm': 'RegistroSeguro!2026',
  }.entries) {
    await t.enterText(find.byKey(Key(e.key)), e.value);
  }
}

Future<void> fillDetails(WidgetTester t) async {
  await details(t);
  await tapVisible(t, find.byKey(const Key('continue_registration')));
}

Future<void> start(
  WidgetTester t,
  Future<http.Response> Function(http.Request) handler,
) async {
  final api = RegistrationApi(client: MockClient(handler));
  addTearDown(api.close);
  await t.pumpWidget(
    WorkNetApp(
      key: UniqueKey(),
      registrationApi: api,
      sessionStore: MemorySessionStore(),
      initialLocation: '/register',
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('vacíos y contraseñas distintas impiden crear y elegir rol', (
    t,
  ) async {
    var calls = 0;
    await start(t, (_) async {
      calls++;
      return created();
    });
    await tapVisible(t, find.byKey(const Key('continue_registration')));
    expect(find.text('Escribe tu nombre completo.'), findsOneWidget);
    expect(calls, 0);
    await details(t);
    await t.enterText(
      find.byKey(const Key('password_confirm')),
      'Distinta!2026',
    );
    await tapVisible(t, find.byKey(const Key('continue_registration')));
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(find.byKey(const Key('role_empresa')), findsNothing);
    expect(calls, 0);
  });
  for (final role in ['candidato', 'empresa']) {
    testWidgets(
      'crea la cuenta antes de elegir $role y guarda rol sin reenviar contraseña',
      (t) async {
        final paths = <String>[];
        await start(t, (request) async {
          paths.add(request.url.path);
          final body = jsonDecode(request.body);
          if (request.url.path.endsWith('/register/')) {
            expect(body.containsKey('role'), false);
            return created();
          }
          expect(body, {'registration_token': 'ticket-qa', 'role': role});
          return selected(role);
        });
        await fillDetails(t);
        expect(paths, ['/api/register/']);
        expect(find.text('Candidato'), findsOneWidget);
        expect(find.text('Empresa'), findsOneWidget);
        expect(find.textContaining('Administrador'), findsNothing);
        expect(
          t
              .widget<FilledButton>(
                find.byKey(const Key('submit_registration')),
              )
              .onPressed,
          isNull,
        );
        await tapVisible(t, find.byKey(Key('role_$role')));
        await tapVisible(t, find.byKey(const Key('submit_registration')));
        expect(paths, ['/api/register/', '/api/register/role/']);
        expect(find.text('Revisa tu correo'), findsOneWidget);
        expect(
          find.text(
            'Rol de la cuenta: ${role == 'empresa' ? 'Empresa' : 'Candidato'}',
          ),
          findsOneWidget,
        );
        await tapVisible(t, find.byKey(const Key('new_registration')));
        expect(
          t
              .widget<TextFormField>(find.byKey(const Key('password')))
              .controller!
              .text,
          isEmpty,
        );
      },
    );
  }
  testWidgets(
    'correo duplicado permanece en el formulario sin crear ni elegir rol',
    (t) async {
      await start(
        t,
        (_) async => jsonResponse({
          'errors': {
            'email': ['Este correo ya está registrado.'],
          },
        }, 400),
      );
      await fillDetails(t);
      expect(find.text('Este correo ya está registrado.'), findsOneWidget);
      expect(find.byKey(const Key('role_candidato')), findsNothing);
      await t.enterText(find.byKey(const Key('email')), 'nuevo@example.com');
      await t.pumpAndSettle();
      expect(find.text('Este correo ya está registrado.'), findsNothing);
    },
  );
  testWidgets('petición de creación en curso no permite duplicarla', (t) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    await start(t, (_) {
      calls++;
      return pending.future;
    });
    await details(t);
    final button = find.byKey(const Key('continue_registration'));
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pump();
    expect(calls, 1);
    expect(t.widget<FilledButton>(button).onPressed, isNull);
    await t.tap(button);
    await t.pump();
    expect(calls, 1);
    pending.complete(created());
    await t.pumpAndSettle();
    expect(find.byKey(const Key('role_candidato')), findsOneWidget);
  });
  testWidgets('error al guardar rol se reintenta sin crear otra cuenta', (
    t,
  ) async {
    var creates = 0, choices = 0;
    await start(t, (r) async {
      if (r.url.path.endsWith('/register/')) {
        creates++;
        return created();
      }
      if (++choices == 1) throw http.ClientException('sin red');
      return selected('candidato');
    });
    await fillDetails(t);
    await tapVisible(t, find.byKey(const Key('role_candidato')));
    await tapVisible(t, find.byKey(const Key('submit_registration')));
    expect(find.textContaining('No pudimos conectarnos'), findsOneWidget);
    await tapVisible(t, find.byKey(const Key('submit_registration')));
    expect(creates, 1);
    expect(choices, 2);
    expect(find.text('Revisa tu correo'), findsOneWidget);
  });
  testWidgets(
    'autorización de rol vencida ofrece volver al login sin anunciar éxito',
    (t) async {
      await start(
        t,
        (r) async => r.url.path.endsWith('/register/')
            ? created()
            : jsonResponse({
                'message': 'La autorización de registro venció.',
              }, 400),
      );
      await fillDetails(t);
      await tapVisible(t, find.byKey(const Key('role_empresa')));
      await tapVisible(t, find.byKey(const Key('submit_registration')));
      expect(find.text('La autorización de registro venció.'), findsOneWidget);
      expect(find.text('Revisa tu correo'), findsNothing);
      expect(
        find.text('Elegir más tarde. Ir a iniciar sesión'),
        findsOneWidget,
      );
    },
  );
  for (final size in [
    const Size(360, 780),
    const Size(390, 844),
    const Size(1440, 960),
  ]) {
    testWidgets(
      'registro, elección posterior y confirmación sin overflow en $size',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = size;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await start(
          t,
          (r) async => r.url.path.endsWith('/register/')
              ? created()
              : selected('candidato'),
        );
        await fillDetails(t);
        await tapVisible(t, find.byKey(const Key('role_candidato')));
        await tapVisible(t, find.byKey(const Key('submit_registration')));
        expect(t.takeException(), isNull);
        expect(find.text('Revisa tu correo'), findsOneWidget);
      },
    );
  }
}
