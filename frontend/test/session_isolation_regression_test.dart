import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/app.dart';
import 'package:worknet/features/access/data/access_repository.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/access/presentation/choose_role_page.dart';
import 'package:worknet/features/account/data/account_repository.dart';
import 'package:worknet/features/account/presentation/account_page.dart';
import 'package:worknet/features/company/data/company_repository.dart';
import 'package:worknet/features/company/presentation/company_reviews_page.dart';
import 'package:worknet/features/profile/data/profile_repository.dart';
import 'package:worknet/features/profile/presentation/profile_page.dart';
import 'support/access_fakes.dart';
import 'profile_test.dart' show profile;

void main() {
  testWidgets('WorkNet elimina datos de A al aceptar B con el mismo rol', (
    t,
  ) async {
    final pendingB = Completer<http.Response>();
    final store = MemorySessionStore()..value = jsonEncode(sessionData());
    final api = WorkNetApi(
      client: MockClient((r) async {
        if (r.url.path.endsWith('notifications/')) {
          return jsonResponse({
            'preferences': {'push_notifications': false},
          });
        }
        if (r.headers['Authorization'] == 'Token token-B') {
          return pendingB.future;
        }
        return jsonResponse({'user': sessionData()['user']});
      }),
    );
    addTearDown(api.close);
    await t.pumpWidget(
      WorkNetApp(api: api, sessionStore: store, initialLocation: '/account'),
    );
    await t.pumpAndSettle();
    final previous = t.state(find.byType(AccountPage));
    final controller = t
        .widget<AccountPage>(find.byType(AccountPage))
        .controller;
    expect(find.text('Candidata QA'), findsOneWidget);
    await controller.completeMfa(
      const UserSession(
        token: 'token-B',
        id: 2,
        name: 'Cuenta B',
        email: 'b@worknet.test',
        role: 'candidato',
      ),
      remember: true,
    );
    await t.pump();
    await t.pump();
    expect(previous.mounted, false);
    expect(find.text('Candidata QA'), findsNothing);
    pendingB.complete(
      jsonResponse({
        'user': {
          'id': 2,
          'full_name': 'Cuenta B',
          'email': 'b@worknet.test',
          'role': 'candidato',
          'email_verified': true,
        },
      }),
    );
    await t.pumpAndSettle();
    expect(find.text('Cuenta B'), findsOneWidget);
    expect(jsonDecode(store.value!)['token'], 'token-B');
  });
  Future<(SessionController, MemorySessionStore, WorkNetApi)> setup(
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final store = MemorySessionStore()..value = jsonEncode(sessionData());
    final api = WorkNetApi(client: MockClient(handler));
    final controller = SessionController(
      repository: HttpAccessRepository(api, store),
    );
    await controller.restore();
    addTearDown(controller.dispose);
    addTearDown(api.close);
    return (controller, store, api);
  }

  Future<void> switchUser(SessionController controller) =>
      controller.completeMfa(
        const UserSession(
          token: 'token-B',
          id: 2,
          name: 'Cuenta B',
          email: 'b@worknet.test',
          role: 'candidato',
        ),
        remember: true,
      );
  void intact(SessionController controller, MemorySessionStore store) {
    expect(controller.session!.id, 2);
    expect(controller.session!.token, 'token-B');
    expect(controller.session!.name, 'Cuenta B');
    expect(jsonDecode(store.value!)['token'], 'token-B');
  }

  for (final area in ['cuenta', 'perfil', 'revisión empresarial']) {
    testWidgets('401 pendiente de $area no cierra la nueva sesión', (t) async {
      final pending = Completer<http.Response>();
      final (session, store, api) = await setup(
        (r) async => r.url.path.endsWith('notifications/')
            ? jsonResponse({
                'preferences': {'push_notifications': false},
              })
            : pending.future,
      );
      final page = switch (area) {
        'cuenta' => AccountPage(
          controller: session,
          repository: HttpAccountRepository(api),
        ),
        'perfil' => ProfilePage(
          controller: session,
          repository: HttpProfileRepository(api),
        ),
        _ => CompanyReviewsPage(
          session: session,
          repository: HttpCompanyRepository(api),
        ),
      };
      await t.pumpWidget(MaterialApp(home: page));
      await t.pump();
      await switchUser(session);
      pending.complete(jsonResponse({'detail': 'Sesión A revocada'}, 401));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      intact(session, store);
      expect(find.text('Sesión A revocada'), findsNothing);
    });
  }
  testWidgets('perfil tardío no encadena fotografía con credenciales de B', (
    t,
  ) async {
    final pending = Completer<http.Response>();
    var photos = 0;
    final (session, store, api) = await setup((r) async {
      if (r.url.path.endsWith('/photo/')) {
        photos++;
        return jsonResponse({});
      }
      return pending.future;
    });
    await t.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          controller: session,
          repository: HttpProfileRepository(api),
        ),
      ),
    );
    await t.pump();
    await switchUser(session);
    pending.complete(
      jsonResponse(
        profile(exists: true, summary: 'Datos privados de A', photo: true),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    intact(session, store);
    expect(photos, 0);
    expect(find.text('Datos privados de A'), findsNothing);
  });
  for (final operation in ['contraseña', 'nombre']) {
    testWidgets('éxito tardío de $operation de A no modifica B', (t) async {
      final pending = Completer<http.Response>();
      final (session, store, api) = await setup((r) async {
        if (r.method != 'GET') return pending.future;
        return r.url.path.endsWith('notifications/')
            ? jsonResponse({
                'preferences': {'push_notifications': false},
              })
            : jsonResponse({'user': sessionData()['user']});
      });
      await t.pumpWidget(
        MaterialApp(
          home: AccountPage(
            controller: session,
            repository: HttpAccountRepository(api),
          ),
        ),
      );
      await t.pumpAndSettle();
      if (operation == 'contraseña') {
        for (final key in [
          'account_current_password',
          'account_new_password',
          'account_confirm_password',
        ]) {
          await t.enterText(find.byKey(Key(key)), 'ContraseñaQA!2026');
        }
      } else {
        await t.enterText(
          find.byKey(const Key('account_name')),
          'Nombre nuevo A',
        );
      }
      final save = find.byKey(
        Key(
          operation == 'contraseña'
              ? 'save_account_password'
              : 'save_account_name',
        ),
      );
      await t.ensureVisible(save);
      await t.tap(save);
      await t.pump();
      await switchUser(session);
      pending.complete(
        jsonResponse(
          operation == 'contraseña'
              ? {'token': 'nuevo-token-A'}
              : {
                  'user': {
                    ...sessionData()['user'] as Map,
                    'full_name': 'Nombre nuevo A',
                  },
                },
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      intact(session, store);
      expect(
        find.text('Contraseña actualizada. Tu sesión sigue activa.'),
        findsNothing,
      );
    });
  }
  testWidgets('elección de rol tardía no cambia la nueva cuenta', (t) async {
    final pending = Completer<http.Response>();
    final (session, store, api) = await setup((_) => pending.future);
    await t.pumpWidget(
      MaterialApp(
        home: ChooseRolePage(
          session: session,
          repository: HttpAccessRepository(api, store),
        ),
      ),
    );
    await t.tap(find.text('Empresa'));
    await t.pump();
    await switchUser(session);
    pending.complete(
      jsonResponse({
        'user': {...sessionData(role: 'empresa')['user'] as Map},
      }),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    intact(session, store);
    expect(session.session!.role, 'candidato');
  });
}
