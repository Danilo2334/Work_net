import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/app.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/access/session.dart';

import 'support/access_fakes.dart';

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> start(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler, {
  MemorySessionStore? store,
  String path = '/account',
}) async {
  final api = WorkNetApi(client: MockClient(handler));
  addTearDown(api.close);
  await tester.pumpWidget(
    WorkNetApp(
      api: api,
      sessionStore:
          store ?? (MemorySessionStore()..value = jsonEncode(sessionData())),
      initialLocation: path,
    ),
  );
  await tester.pumpAndSettle();
}

http.Response accountGet(http.Request request) =>
    request.url.path.endsWith('notifications/')
    ? jsonResponse({
        'preferences': {'push_notifications': true},
      })
    : jsonResponse({'user': sessionData()['user']});

Future<void> passwords(
  WidgetTester tester, {
  String confirm = 'Nueva!2026abc',
}) async {
  await tester.enterText(
    find.byKey(const Key('account_current_password')),
    'Anterior!2026abc',
  );
  await tester.enterText(
    find.byKey(const Key('account_new_password')),
    'Nueva!2026abc',
  );
  await tester.enterText(
    find.byKey(const Key('account_confirm_password')),
    confirm,
  );
}

void main() {
  testWidgets('configuración protegida no consulta API sin sesión', (
    tester,
  ) async {
    var calls = 0;
    await start(tester, (_) async {
      calls++;
      return jsonResponse({});
    }, store: MemorySessionStore());
    expect(find.byKey(const Key('submit_login')), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets(
    'dashboard abre configuración y correo/rol/verificación son solo lectura',
    (tester) async {
      await start(
        tester,
        (r) async => r.url.path.endsWith('candidate/')
            ? jsonResponse(dashboardData())
            : accountGet(r),
        path: '/dashboard',
      );
      await tap(tester, 'open_account');
      expect(find.byKey(const Key('account_email')), findsOneWidget);
      expect(find.text('Rol: Candidato'), findsOneWidget);
      expect(find.text('Correo verificado'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4));
    },
  );

  testWidgets(
    'PATCH envía solo full_name y conserva el nombre tras nueva consulta y en sesión',
    (tester) async {
      var name = 'Candidata QA';
      final store = MemorySessionStore()..value = jsonEncode(sessionData());
      await start(tester, (r) async {
        if (r.method == 'PATCH') {
          expect(jsonDecode(r.body), {'full_name': 'Nombre actualizado QA'});
          name = jsonDecode(r.body)['full_name'];
        }
        if (r.url.path.endsWith('candidate/')) {
          return jsonResponse(dashboardData());
        }
        if (r.url.path.endsWith('notifications/')) return accountGet(r);
        return jsonResponse({
          'user': {...sessionData()['user'] as Map, 'full_name': name},
        });
      }, store: store);
      await tester.enterText(
        find.byKey(const Key('account_name')),
        ' Nombre actualizado QA ',
      );
      await tap(tester, 'save_account_name');
      expect(find.text('Nombre actualizado correctamente.'), findsOneWidget);
      expect(jsonDecode(store.value!)['user']['full_name'], name);
      await tap(tester, 'close_account');
      await tap(tester, 'open_account');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('account_name')))
            .controller!
            .text,
        name,
      );
    },
  );

  testWidgets(
    'preferencias envía un booleano y respeta el valor al volver a consultar',
    (tester) async {
      var push = true;
      await start(tester, (r) async {
        if (r.url.path.endsWith('notifications/')) {
          if (r.method == 'PATCH') {
            expect(jsonDecode(r.body), {'push_notifications': false});
            expect(r.headers['Authorization'], 'Token qa-token');
            push = false;
          }
          return jsonResponse({
            'preferences': {'push_notifications': push},
          });
        }
        return r.url.path.endsWith('candidate/')
            ? jsonResponse(dashboardData())
            : accountGet(r);
      });
      await tap(tester, 'account_push');
      await tap(tester, 'save_account_preferences');
      expect(
        find.text('Preferencias guardadas correctamente.'),
        findsOneWidget,
      );
      await tap(tester, 'close_account');
      await tap(tester, 'open_account');
      expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('account_push')))
            .value,
        false,
      );
    },
  );

  testWidgets('contraseñas diferentes no envían la solicitud', (tester) async {
    var writes = 0;
    await start(tester, (r) async {
      if (r.method != 'GET') writes++;
      return accountGet(r);
    });
    await passwords(tester, confirm: 'Distinta!2026');
    await tap(tester, 'save_account_password');
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(writes, 0);
  });

  testWidgets('contraseña actual incorrecta muestra rechazo de Django', (
    tester,
  ) async {
    await start(
      tester,
      (r) async => r.method == 'POST'
          ? jsonResponse({
              'errors': {
                'current_password': ['La contraseña actual es incorrecta.'],
              },
            }, 400)
          : accountGet(r),
    );
    await passwords(tester);
    await tap(tester, 'save_account_password');
    expect(find.text('La contraseña actual es incorrecta.'), findsWidgets);
    expect(
      find.text('Contraseña actualizada. Tu sesión sigue activa.'),
      findsNothing,
    );
  });

  testWidgets(
    'contraseña cambiada sustituye token recordado y lo usa en la siguiente operación',
    (tester) async {
      var changed = false;
      final store = MemorySessionStore()..value = jsonEncode(sessionData());
      await start(tester, (r) async {
        if (r.url.path.endsWith('password/')) {
          expect(jsonDecode(r.body), {
            'current_password': 'Anterior!2026abc',
            'new_password': 'Nueva!2026abc',
            'new_password_confirm': 'Nueva!2026abc',
          });
          changed = true;
          return jsonResponse({'token': 'qa-renovado'});
        }
        if (changed) expect(r.headers['Authorization'], 'Token qa-renovado');
        if (r.url.path.endsWith('notifications/')) {
          return jsonResponse({
            'preferences': {'push_notifications': r.method == 'GET'},
          });
        }
        return accountGet(r);
      }, store: store);
      await passwords(tester);
      await tap(tester, 'save_account_password');
      expect(jsonDecode(store.value!)['token'], 'qa-renovado');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const Key('account_new_password')),
            )
            .controller!
            .text,
        isEmpty,
      );
      await tap(tester, 'account_push');
      await tap(tester, 'save_account_preferences');
      expect(
        find.text('Preferencias guardadas correctamente.'),
        findsOneWidget,
      );
    },
  );

  test(
    'rotación y nombre preservan Recordar sesión activado o desactivado',
    () async {
      for (final remember in [true, false]) {
        final store = MemorySessionStore();
        final api = WorkNetApi(
          client: MockClient((_) async => jsonResponse(sessionData())),
        );
        final controller = SessionController(api: api, store: store);
        await controller.restore();
        await controller.login(
          'qa@example.com',
          'Clave!2026',
          remember: remember,
        );
        await controller.update(token: 'qa-nuevo', name: 'QA actualizado');
        expect(controller.session!.token, 'qa-nuevo');
        expect(controller.session!.name, 'QA actualizado');
        expect(store.value != null, remember);
        final restored = SessionController(api: api, store: store);
        await restored.restore();
        expect(restored.session?.token, remember ? 'qa-nuevo' : null);
        restored.dispose();
        controller.dispose();
        api.close();
      }
    },
  );

  test(
    'fallo al persistir un token rotado exige login y nunca mantiene token anterior en memoria',
    () async {
      final store = MemorySessionStore();
      final api = WorkNetApi(
        client: MockClient((_) async => jsonResponse(sessionData())),
      );
      final controller = SessionController(api: api, store: store);
      await controller.login('qa@example.com', 'Clave!2026', remember: true);
      store.fail = true;
      await expectLater(
        controller.update(token: 'qa-nuevo'),
        throwsA(isA<ApiFailure>()),
      );
      expect(controller.session, isNull);
      controller.dispose();
      api.close();
    },
  );

  testWidgets(
    'eliminación requiere confirmación explícita; cancelar no llama DELETE',
    (tester) async {
      var deletes = 0;
      await start(tester, (r) async {
        if (r.method == 'DELETE') deletes++;
        return accountGet(r);
      });
      await tap(tester, 'request_delete_account');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('submit_delete_account')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('delete_account_password')),
        'Clave!2026',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('submit_delete_account')),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, 'cancel_delete_account');
      expect(deletes, 0);
      expect(find.byKey(const Key('account_name')), findsOneWidget);
    },
  );

  testWidgets('eliminación confirmada envía DELETE JSON y limpia sesión', (
    tester,
  ) async {
    final store = MemorySessionStore()..value = jsonEncode(sessionData());
    await start(tester, (r) async {
      if (r.method == 'DELETE') {
        expect(r.url.path, '/api/account/delete/');
        expect(r.headers['content-type'], contains('application/json'));
        expect(jsonDecode(r.body), {
          'current_password': 'Clave!2026',
          'confirmation': true,
        });
        return jsonResponse({'message': 'Cuenta eliminada correctamente.'});
      }
      return accountGet(r);
    }, store: store);
    await tap(tester, 'request_delete_account');
    await tester.enterText(
      find.byKey(const Key('delete_account_password')),
      'Clave!2026',
    );
    await tap(tester, 'confirm_delete_account');
    await tap(tester, 'submit_delete_account');
    expect(store.value, isNull);
    expect(find.byKey(const Key('submit_login')), findsOneWidget);
  });

  testWidgets('error de carga permite reintentar y un 401 limpia sesión', (
    tester,
  ) async {
    var attempts = 0;
    final store = MemorySessionStore()..value = jsonEncode(sessionData());
    await start(tester, (r) async {
      attempts++;
      return attempts <= 2
          ? http.Response('unavailable', 500)
          : jsonResponse({'detail': 'Invalid token.'}, 401);
    }, store: store);
    expect(find.text('No pudimos cargar tu cuenta'), findsOneWidget);
    await tap(tester, 'retry_account');
    expect(find.byKey(const Key('submit_login')), findsOneWidget);
    expect(store.value, isNull);
  });

  testWidgets('preferencia malformada no se sustituye por un dato inventado', (
    tester,
  ) async {
    await start(
      tester,
      (r) async => r.url.path.endsWith('notifications/')
          ? jsonResponse({
              'preferences': {'push_notifications': 'true'},
            })
          : accountGet(r),
    );
    expect(
      find.text('No pudimos interpretar las preferencias.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('save_account_preferences')), findsNothing);
  });

  testWidgets('configuración y confirmación son utilizables en móvil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await start(tester, (r) async => accountGet(r));
    await tap(tester, 'request_delete_account');
    await tap(tester, 'confirm_delete_account');
    await tap(tester, 'submit_delete_account');
    expect(find.text('Escribe tu contraseña actual.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
