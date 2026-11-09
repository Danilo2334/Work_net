import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/app.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/access/data/access_repository.dart';
import 'package:worknet/features/access/domain/admin_mfa.dart';
import 'package:worknet/features/access/domain/access.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/administration/admin_page.dart';
import 'package:worknet/features/administration/admin_repository.dart';
import 'support/access_fakes.dart';

class DelayedWriteStore extends MemorySessionStore {
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<void> write(String value) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    await super.write(value);
  }
}

Map<String, dynamic> challenge({bool enrollment = false}) => {
  'mfa_required': true,
  'challenge': '12345678-1234-1234-1234-123456789abc',
  'enrollment_required': enrollment,
  'expires_at': '2026-12-01T12:00:00Z',
};
Map<String, dynamic> admin({int id = 2, bool protected = false}) => {
  'id': id,
  'full_name': protected ? 'Principal QA' : 'Revisora QA',
  'email': 'qa$id@worknet.test',
  'administrative_role': protected ? 'principal' : 'revisor',
  'is_active': true,
  'email_verified': true,
  'mfa_enrolled': true,
  'version': 0,
  'protected': protected,
  'permissions': protected
      ? adminPermissionKeys.toList()
      : ['dashboard', 'review_companies', 'view_events'],
};
Map<String, dynamic> listing({
  bool empty = false,
  bool create = true,
  List<String>? myPermissions,
}) => {
  'results': empty ? [] : [admin(id: 1, protected: true), admin()],
  'count': empty ? 0 : 2,
  'page': 1,
  'page_size': 20,
  'can_create': create,
  'my_permissions': myPermissions ?? adminPermissionKeys.toList(),
  'permission_catalog': [
    for (final key in adminPermissionKeys) {'key': key, 'label': key},
  ],
  'roles': [
    {
      'key': 'revisor',
      'permissions': ['dashboard', 'review_companies', 'view_events'],
    },
    {'key': 'gestor', 'permissions': adminPermissionKeys.toList()},
  ],
};
Map<String, dynamic> summary() => {
  'metrics': {'candidates': 4, 'companies': 3, 'pending_companies': 1},
  'notifications': [],
  'recent_events': [],
};
Future<void> tap(WidgetTester t, Finder f) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<MemorySessionStore> start(
  WidgetTester t,
  Future<http.Response> Function(http.Request) handler, {
  String path = '/login',
  bool authenticated = false,
}) async {
  final api = WorkNetApi(client: MockClient(handler));
  addTearDown(api.close);
  final store = MemorySessionStore()
    ..value = authenticated ? jsonEncode(sessionData(role: 'admin')) : null;
  await t.pumpWidget(
    WorkNetApp(
      key: UniqueKey(),
      api: api,
      sessionStore: store,
      initialLocation: path,
    ),
  );
  await t.pumpAndSettle();
  return store;
}

Future<void> login(WidgetTester t) async {
  await t.enterText(
    find.byKey(const Key('login_email')),
    'principal@worknet.test',
  );
  await t.enterText(find.byKey(const Key('login_password')), 'Privada!2026');
  await tap(t, find.byKey(const Key('remember_session')));
  await tap(t, find.byKey(const Key('submit_login')));
}

void main() {
  test(
    'expirar borra escritura pendiente aunque otro login quede en MFA o falle',
    () async {
      for (final status in [202, 400]) {
        final store = DelayedWriteStore();
        final api = WorkNetApi(
          client: MockClient(
            (_) async => jsonResponse(
              status == 202
                  ? challenge()
                  : {'message': 'Contraseña incorrecta'},
              status,
            ),
          ),
        );
        final lifecycle = SessionLifecycle(HttpAccessRepository(api, store));
        final accepting = lifecycle.accept(
          SessionModel.parse(sessionData(role: 'admin')),
          true,
        );
        await store.started.future;
        final expiring = lifecycle.expire();
        await expectLater(
          lifecycle.login('new@worknet.test', 'Privada', true),
          throwsA(isA<ApiFailure>()),
        );
        store.release.complete();
        await Future.wait([accepting, expiring]);
        expect(lifecycle.current, isNull);
        expect(store.value, isNull);
        api.close();
      }
    },
  );
  test(
    'aceptación pendiente no restaura sesión ni credencial tras expirar',
    () async {
      final store = DelayedWriteStore();
      final api = WorkNetApi(client: MockClient((_) async => jsonResponse({})));
      addTearDown(api.close);
      final lifecycle = SessionLifecycle(HttpAccessRepository(api, store));
      final accepting = lifecycle.accept(
        SessionModel.parse(sessionData(role: 'admin')),
        true,
      );
      await store.started.future;
      final expiring = lifecycle.expire();
      expect(lifecycle.current, isNull);
      store.release.complete();
      await Future.wait([accepting, expiring]);
      expect(lifecycle.current, isNull);
      expect(store.value, isNull);
    },
  );

  testWidgets('401 tardío de otra cuenta no expira la sesión actual', (
    t,
  ) async {
    final delayed = Completer<http.Response>();
    final api = WorkNetApi(client: MockClient((_) => delayed.future));
    addTearDown(api.close);
    final store = MemorySessionStore()
      ..value = jsonEncode(sessionData(role: 'admin'));
    final session = SessionController(
      repository: HttpAccessRepository(api, store),
    );
    addTearDown(session.dispose);
    await session.restore();
    await t.pumpWidget(
      MaterialApp(
        home: AdminAccountsPage(
          session: session,
          repository: HttpAdminRepository(api),
        ),
      ),
    );
    await t.pump();
    await session.completeMfa(
      SessionModel.parse(sessionData(role: 'admin', token: 'new-token')),
      remember: false,
    );
    delayed.complete(jsonResponse({'message': 'Anterior revocada'}, 401));
    await t.pumpAndSettle();
    expect(session.session?.token, 'new-token');
  });
  test(
    'contrato exige MFA y nunca almacena desafío o sesión admin sin factor',
    () async {
      final store = MemorySessionStore();
      final api = WorkNetApi(
        client: MockClient((_) async => jsonResponse(challenge(), 202)),
      );
      addTearDown(api.close);
      final controller = SessionController(
        repository: HttpAccessRepository(api, store),
      );
      addTearDown(controller.dispose);
      await controller.restore();
      await expectLater(
        controller.login('x@worknet.test', 'Privada', remember: true),
        throwsA(isA<MfaRequired>()),
      );
      expect(controller.session, isNull);
      expect(store.value, isNull);
      final invalid = sessionData(role: 'admin');
      (invalid['user'] as Map).remove('mfa_verified');
      expect(() => SessionModel.parse(invalid), throwsA(isA<ApiFailure>()));
      final invalidChallenge = {...challenge(), 'token': 'must-not-be-used'};
      expect(() => parseMfa(invalidChallenge), throwsA(isA<ApiFailure>()));
    },
  );

  testWidgets(
    'contraseña no entra al dashboard, OTP inválido reintenta y solo OTP confirmado guarda sesión',
    (t) async {
      var attempts = 0;
      final store = await start(t, (r) async {
        if (r.url.path.endsWith('/login/')) {
          return jsonResponse(challenge(), 202);
        }
        if (r.url.path.endsWith('/mfa/verify/')) {
          attempts++;
          expect(jsonDecode(r.body)['challenge'], challenge()['challenge']);
          return attempts == 1
              ? jsonResponse({'message': 'Código utilizado.'}, 400)
              : jsonResponse(sessionData(role: 'admin'));
        }
        return jsonResponse(summary());
      });
      await login(t);
      expect(find.text('Verificar doble factor'), findsOneWidget);
      expect(find.text('Candidatos registrados: 4'), findsNothing);
      expect(store.value, isNull);
      await t.enterText(find.byKey(const Key('mfa_code')), '123456');
      await tap(t, find.byKey(const Key('mfa_verify')));
      expect(find.text('Código utilizado.'), findsOneWidget);
      expect(store.value, isNull);
      await tap(t, find.byKey(const Key('mfa_verify')));
      expect(find.text('Candidatos registrados: 4'), findsOneWidget);
      expect(store.value, isNotNull);
    },
  );

  testWidgets(
    'enrolamiento oculta semilla y backup, exige guardar códigos y no persiste antes de confirmar',
    (t) async {
      final store = await start(t, (r) async {
        if (r.url.path.endsWith('/login/')) {
          return jsonResponse(challenge(enrollment: true), 202);
        }
        if (r.url.path.endsWith('/mfa/setup/')) {
          return jsonResponse({'secret': 'A' * 32});
        }
        if (r.url.path.endsWith('/mfa/verify/')) {
          return jsonResponse({
            ...sessionData(role: 'admin'),
            'recovery_codes': List.generate(
              8,
              (i) => i.toString().padLeft(32, '0'),
            ),
          });
        }
        return jsonResponse(summary());
      });
      await login(t);
      await tap(t, find.byKey(const Key('mfa_setup')));
      expect(find.byKey(const Key('mfa_private_secret')), findsNothing);
      await t.enterText(find.byKey(const Key('mfa_code')), '123456');
      await tap(t, find.byKey(const Key('mfa_verify')));
      expect(find.text('Autenticador confirmado'), findsOneWidget);
      expect(find.byKey(const Key('mfa_private_recovery')), findsNothing);
      expect(store.value, isNull);
      expect(
        t.widget<FilledButton>(find.byKey(const Key('mfa_continue'))).onPressed,
        isNull,
      );
      await tap(t, find.byKey(const Key('mfa_codes_saved')));
      await tap(t, find.byKey(const Key('mfa_continue')));
      expect(store.value, isNotNull);
      expect(find.byKey(const Key('mfa_code')), findsNothing);
    },
  );

  testWidgets(
    'recuperación vuelve a configurar autenticador y cancelar borra el flujo',
    (t) async {
      final store = await start(t, (r) async {
        if (r.url.path.endsWith('/login/')) {
          return jsonResponse(challenge(), 202);
        }
        expect(jsonDecode(r.body)['recovery'], true);
        return jsonResponse(challenge(enrollment: true), 202);
      });
      await login(t);
      await tap(t, find.byKey(const Key('mfa_use_recovery')));
      await t.enterText(find.byKey(const Key('mfa_code')), 'a' * 32);
      await tap(t, find.byKey(const Key('mfa_verify')));
      expect(find.text('Configurar doble factor'), findsOneWidget);
      expect(
        t.widget<TextField>(find.byKey(const Key('mfa_code'))).controller!.text,
        isEmpty,
      );
      expect(store.value, isNull);
      await tap(t, find.byKey(const Key('mfa_cancel')));
      expect(find.byKey(const Key('login_password')), findsOneWidget);
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('login_password')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'listado protege principal y guarda alta con rol y permisos sin flags privilegiados',
    (t) async {
      Map<String, dynamic>? sent;
      await start(
        t,
        (r) async {
          if (r.method == 'POST') {
            sent = jsonDecode(r.body);
            return jsonResponse({'administrator': admin()}, 201);
          }
          return jsonResponse(listing());
        },
        authenticated: true,
        path: '/admin/accounts',
      );
      expect(
        t
            .widget<OutlinedButton>(find.byKey(const Key('admin_edit_1')))
            .onPressed,
        isNull,
      );
      await tap(t, find.byKey(const Key('admin_create')));
      await t.enterText(find.byKey(const Key('admin_name')), 'Nueva QA');
      await t.enterText(
        find.byKey(const Key('admin_email')),
        'nueva@worknet.test',
      );
      await t.enterText(
        find.byKey(const Key('admin_password')),
        'Privada!2026',
      );
      await tap(t, find.byKey(const Key('admin_save')));
      expect(sent!['administrative_role'], 'revisor');
      expect(sent!['permissions'], [
        'dashboard',
        'review_companies',
        'view_events',
      ]);
      expect(sent!.containsKey('is_staff'), false);
      expect(sent!.containsKey('is_superuser'), false);
      expect(find.byKey(const Key('admin_success')), findsOneWidget);
    },
  );

  testWidgets(
    'permisos y estado incluyen versión, conflicto no anuncia guardado',
    (t) async {
      Map<String, dynamic>? sent;
      await start(
        t,
        (r) async {
          if (r.method == 'PATCH') {
            sent = jsonDecode(r.body);
            return jsonResponse({
              'message': 'La cuenta cambió. Actualiza.',
            }, 409);
          }
          return jsonResponse(listing());
        },
        authenticated: true,
        path: '/admin/accounts',
      );
      await tap(t, find.byKey(const Key('admin_edit_2')));
      await tap(t, find.byKey(const Key('admin_permission_review_companies')));
      await tap(t, find.byKey(const Key('admin_active')));
      await tap(t, find.byKey(const Key('admin_save')));
      expect(sent!['version'], 0);
      expect(sent!['is_active'], false);
      expect(sent!['permissions'], ['dashboard', 'view_events']);
      expect(find.text('La cuenta cambió. Actualiza.'), findsOneWidget);
      expect(find.byKey(const Key('admin_success')), findsNothing);
    },
  );

  testWidgets('carga error reintento vacío y sesión revocada', (t) async {
    var calls = 0;
    await start(
      t,
      (r) async {
        calls++;
        return calls == 1
            ? jsonResponse({'message': 'Sin servicio'}, 503)
            : calls == 2
            ? jsonResponse(listing(empty: true))
            : jsonResponse({'message': 'Sesión revocada'}, 401);
      },
      authenticated: true,
      path: '/admin/accounts',
    );
    expect(find.text('Reintentar'), findsOneWidget);
    await tap(t, find.text('Reintentar'));
    expect(
      find.text('No hay cuentas administrativas para mostrar.'),
      findsOneWidget,
    );
    await tap(t, find.text('Actualizar listado'));
    expect(find.byKey(const Key('login_email')), findsOneWidget);
    expect(find.text('Administradores y permisos'), findsNothing);
  });

  testWidgets('respuesta tardía tras salida nunca muestra cuentas privadas', (
    t,
  ) async {
    final delayed = Completer<http.Response>();
    final api = WorkNetApi(client: MockClient((_) => delayed.future));
    addTearDown(api.close);
    final store = MemorySessionStore()
      ..value = jsonEncode(sessionData(role: 'admin'));
    final session = SessionController(
      repository: HttpAccessRepository(api, store),
    );
    addTearDown(session.dispose);
    await session.restore();
    await t.pumpWidget(
      MaterialApp(
        home: AdminAccountsPage(
          session: session,
          repository: HttpAdminRepository(api),
        ),
      ),
    );
    await t.pump();
    await session.expire();
    delayed.complete(jsonResponse(listing()));
    await t.pumpAndSettle();
    expect(find.text('Revisora QA'), findsNothing);
  });

  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('administración y editor legibles en $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await start(
        t,
        (_) async => jsonResponse(listing()),
        authenticated: true,
        path: '/admin/accounts',
      );
      await tap(t, find.byKey(const Key('admin_edit_2')));
      expect(t.takeException(), isNull);
    });
  }
}
