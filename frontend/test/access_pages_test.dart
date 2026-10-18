import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/app.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'support/access_fakes.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<MemorySessionStore> start(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler, {
  String path = '/login',
  MemorySessionStore? store,
}) async {
  final api = WorkNetApi(client: MockClient(handler));
  addTearDown(api.close);
  final memory = store ?? MemorySessionStore();
  await tester.pumpWidget(
    WorkNetApp(
      key: UniqueKey(),
      api: api,
      sessionStore: memory,
      initialLocation: path,
    ),
  );
  await tester.pumpAndSettle();
  return memory;
}

Future<void> fillLogin(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('login_email')),
    'qa@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('login_password')),
    'Secreto!2026',
  );
}

void main() {
  testWidgets(
    'abrir directamente el dashboard reconstruye la vista tras restaurar sesión',
    (tester) async {
      final store = _DelayedSessionStore()..value = jsonEncode(sessionData());
      await start(
        tester,
        (_) async => jsonResponse(dashboardData()),
        path: '/dashboard',
        store: store,
      );
      expect(find.text('Oferta QA desde API'), findsOneWidget);
    },
  );
  testWidgets('login valida obligatorios y enlaza registro y recuperación', (
    tester,
  ) async {
    var calls = 0;
    await start(tester, (_) async {
      calls++;
      return jsonResponse({});
    });
    await tap(tester, find.byKey(const Key('submit_login')));
    expect(find.text('Escribe tu correo electrónico.'), findsOneWidget);
    expect(find.text('Escribe tu contraseña.'), findsOneWidget);
    expect(calls, 0);
    await tap(tester, find.text('¿Aún no tienes cuenta? Regístrate'));
    expect(find.text('Crea tu cuenta'), findsOneWidget);
    await tap(tester, find.text('Ya tengo cuenta. Iniciar sesión'));
    await tap(tester, find.text('¿Olvidaste tu contraseña?'));
    expect(find.text('Recuperar contraseña'), findsOneWidget);
  });

  testWidgets(
    'credenciales incorrectas muestran el error y permiten reintentar',
    (tester) async {
      await start(
        tester,
        (_) async => jsonResponse({
          'errors': {
            'non_field_errors': ['Correo o contraseña incorrectos.'],
          },
        }, 400),
      );
      await fillLogin(tester);
      await tap(tester, find.byKey(const Key('submit_login')));
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('submit_login')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'login candidato consume API con token y logout elimina sesión recordada',
    (tester) async {
      final store = await start(tester, (request) async {
        if (request.url.path.endsWith('login/')) {
          return jsonResponse(sessionData());
        }
        expect(request.headers['Authorization'], 'Token qa-token');
        return jsonResponse(dashboardData());
      });
      await fillLogin(tester);
      await tap(tester, find.byKey(const Key('remember_session')));
      await tap(tester, find.byKey(const Key('submit_login')));
      expect(find.text('Hola, Candidata QA'), findsOneWidget);
      expect(find.text('Oferta QA desde API'), findsOneWidget);
      expect(store.value, isNotNull);
      await tap(tester, find.byKey(const Key('logout')));
      expect(find.byKey(const Key('submit_login')), findsOneWidget);
      expect(store.value, isNull);
    },
  );

  testWidgets(
    'empresa y administrador no reciben estados ni dashboards inventados',
    (tester) async {
      for (final role in ['empresa', 'admin']) {
        await start(tester, (_) async => jsonResponse(sessionData(role: role)));
        await fillLogin(tester);
        await tap(tester, find.byKey(const Key('submit_login')));
        expect(find.text('Inicio de sesión correcto'), findsOneWidget);
        expect(
          find.textContaining('todavía no está disponible'),
          findsOneWidget,
        );
        expect(find.textContaining('Hola,'), findsNothing);
        await tap(tester, find.text('Cerrar sesión'));
      }
    },
  );

  testWidgets('dashboard permite reintentar y muestra vacío con datos de API', (
    tester,
  ) async {
    var attempt = 0;
    final store = MemorySessionStore()..value = jsonEncode(sessionData());
    await start(
      tester,
      (_) async => ++attempt == 1
          ? http.Response('unavailable', 500)
          : jsonResponse(dashboardData(empty: true)),
      store: store,
    );
    expect(find.text('No pudimos cargar tu dashboard'), findsOneWidget);
    await tap(tester, find.byKey(const Key('retry_dashboard')));
    expect(
      find.textContaining('Todavía no hay trabajos publicados'),
      findsOneWidget,
    );
    expect(find.text('Completitud del perfil · 67%'), findsOneWidget);
    expect(find.text('Tus accesos'), findsOneWidget);
  });

  testWidgets('un 401 limpia sesión persistida y vuelve al login', (
    tester,
  ) async {
    final store = MemorySessionStore()..value = jsonEncode(sessionData());
    await start(
      tester,
      (_) async => jsonResponse({'detail': 'Invalid token'}, 401),
      store: store,
    );
    expect(find.byKey(const Key('submit_login')), findsOneWidget);
    expect(
      find.text('Tu sesión ya no es válida. Inicia sesión de nuevo.'),
      findsOneWidget,
    );
    expect(store.value, isNull);
  });

  testWidgets('dashboard presenta carga mientras espera al servidor', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final api = WorkNetApi(client: MockClient((_) => response.future));
    addTearDown(api.close);
    final store = MemorySessionStore()..value = jsonEncode(sessionData());
    await tester.pumpWidget(
      WorkNetApp(api: api, sessionStore: store, initialLocation: '/login'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Cargando tu dashboard…'), findsOneWidget);
    response.complete(jsonResponse(dashboardData()));
    await tester.pumpAndSettle();
    expect(find.text('Oferta QA desde API'), findsOneWidget);
  });

  testWidgets('solicitud de recuperación es genérica y maneja error SMTP', (
    tester,
  ) async {
    var calls = 0;
    await start(tester, (request) async {
      expect(jsonDecode(request.body), {'email': 'qa@example.com'});
      return ++calls == 1
          ? http.Response('SMTP_PRIVATE', 500)
          : jsonResponse({'message': 'Si el correo está registrado'});
    }, path: '/forgot-password');
    await tester.enterText(
      find.byKey(const Key('recovery_email')),
      ' QA@EXAMPLE.COM ',
    );
    await tap(tester, find.byKey(const Key('request_recovery')));
    expect(find.textContaining('No pudimos enviar el enlace'), findsOneWidget);
    expect(find.text('Revisa tu correo'), findsNothing);
    await tap(tester, find.byKey(const Key('request_recovery')));
    expect(find.text('Revisa tu correo'), findsOneWidget);
    expect(find.textContaining('Si el correo está registrado'), findsOneWidget);
  });

  testWidgets(
    'confirmación bloquea contraseñas distintas y confirma cambio de API',
    (tester) async {
      var calls = 0;
      await start(tester, (request) async {
        calls++;
        expect(jsonDecode(request.body)['uid'], 'MQ');
        return jsonResponse({
          'message': 'Contraseña restablecida correctamente.',
        });
      }, path: '/reset-password?uid=MQ&token=qa-link');
      await tester.enterText(
        find.byKey(const Key('new_password')),
        'Nueva!2026',
      );
      await tester.enterText(
        find.byKey(const Key('new_password_confirm')),
        'Diferente!2026',
      );
      await tap(tester, find.byKey(const Key('confirm_recovery')));
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(calls, 0);
      await tester.enterText(
        find.byKey(const Key('new_password_confirm')),
        'Nueva!2026',
      );
      await tap(tester, find.byKey(const Key('confirm_recovery')));
      expect(find.text('Contraseña actualizada'), findsOneWidget);
      expect(calls, 1);
      expect(find.byKey(const Key('new_password')), findsNothing);
      await tap(tester, find.text('Iniciar sesión'));
      expect(find.byKey(const Key('submit_login')), findsOneWidget);
    },
  );

  testWidgets('enlace ausente o vencido no muestra éxito y ofrece pedir otro', (
    tester,
  ) async {
    await start(tester, (_) async => jsonResponse({}), path: '/reset-password');
    expect(
      find.textContaining('El enlace de recuperación no es válido'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('confirm_recovery')), findsNothing);
    await start(
      tester,
      (_) async => jsonResponse({
        'errors': {
          'token': ['El enlace es inválido o ha expirado.'],
        },
      }, 400),
      path: '/reset-password?uid=MQ&token=expired',
    );
    await tester.enterText(find.byKey(const Key('new_password')), 'Nueva!2026');
    await tester.enterText(
      find.byKey(const Key('new_password_confirm')),
      'Nueva!2026',
    );
    await tap(tester, find.byKey(const Key('confirm_recovery')));
    expect(find.text('El enlace es inválido o ha expirado.'), findsOneWidget);
    expect(find.text('Contraseña actualizada'), findsNothing);
  });

  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('acceso, recuperación y dashboard sin overflow en $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final path in [
        '/login',
        '/forgot-password',
        '/reset-password?uid=MQ&token=qa',
      ]) {
        await start(tester, (_) async => jsonResponse({}), path: path);
        expect(tester.takeException(), isNull);
      }
      await start(
        tester,
        (_) async => jsonResponse(dashboardData()),
        store: MemorySessionStore()..value = jsonEncode(sessionData()),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Oferta QA desde API'), findsOneWidget);
    });
  }
}

class _DelayedSessionStore extends MemorySessionStore {
  @override
  Future<String?> read() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return value;
  }
}
