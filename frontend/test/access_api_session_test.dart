import 'package:worknet/features/dashboard/data/dashboard_repository.dart';
import 'package:worknet/features/access/data/access_repository.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'support/access_fakes.dart';

void main() {
  test(
    'login normaliza correo, preserva contraseña y guarda solo con Recordar sesión',
    () async {
      final store = MemorySessionStore();
      final api = WorkNetApi(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/logout/')) {
            expect(request.headers['Authorization'], 'Token qa-token');
            return jsonResponse({'message': 'Sesión cerrada.'});
          }
          expect(request.url.path, '/api/login/');
          expect(jsonDecode(request.body), {
            'email': 'qa@example.com',
            'password': '  ClaveExacta!2026  ',
          });
          expect(request.headers.containsKey('Authorization'), false);
          return jsonResponse(sessionData());
        }),
      );
      addTearDown(api.close);
      final controller = SessionController(
        repository: HttpAccessRepository(api, store),
      );
      addTearDown(controller.dispose);
      await controller.restore();
      await controller.login(
        ' QA@EXAMPLE.COM ',
        '  ClaveExacta!2026  ',
        remember: true,
      );
      expect(controller.session!.role, 'candidato');
      expect(store.value, isNotNull);
      expect(store.value, isNot(contains('ClaveExacta')));
      final restored = SessionController(
        repository: HttpAccessRepository(api, store),
      );
      addTearDown(restored.dispose);
      await restored.restore();
      expect(restored.session!.token, 'qa-token');
      await controller.logout();
      expect(store.value, isNull);
      expect(controller.session, isNull);
      await controller.login(
        'qa@example.com',
        '  ClaveExacta!2026  ',
        remember: false,
      );
      expect(store.value, isNull);
    },
  );

  test('sesión corrupta se elimina y no concede acceso', () async {
    final store = MemorySessionStore()..value = '{"token":"invalid"}';
    final api = WorkNetApi();
    addTearDown(api.close);
    final controller = SessionController(
      repository: HttpAccessRepository(api, store),
    );
    addTearDown(controller.dispose);
    await controller.restore();
    expect(controller.session, isNull);
    expect(store.value, isNull);
    expect(controller.notice, contains('Inicia sesión'));
  });

  test(
    'fallo de almacenamiento no anuncia sesión guardada ni logout exitoso',
    () async {
      final store = MemorySessionStore()..fail = true;
      final api = WorkNetApi(
        client: MockClient((_) async => jsonResponse(sessionData())),
      );
      addTearDown(api.close);
      final controller = SessionController(
        repository: HttpAccessRepository(api, store),
      );
      addTearDown(controller.dispose);
      await expectLater(
        controller.login('qa@example.com', 'Secreto!2026', remember: true),
        throwsA(isA<ApiFailure>()),
      );
      expect(controller.session, isNull);
      store.fail = false;
      await controller.login('qa@example.com', 'Secreto!2026', remember: true);
      store.fail = true;
      await expectLater(controller.logout(), throwsA(isA<ApiFailure>()));
      expect(controller.session, isNotNull);
    },
  );

  test(
    'dashboard usa Authorization Token y no inventa métricas ausentes',
    () async {
      final api = WorkNetApi(
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Token real-qa');
          expect(request.url.path, '/api/dashboard/candidate/');
          return jsonResponse(dashboardData());
        }),
      );
      addTearDown(api.close);
      final summary = CandidateSummaryModel.parse(
        await api.request('dashboard/candidate/', token: 'real-qa'),
      );
      expect(summary.percentage, 67);
      expect(summary.applications, 2);
      expect(summary.jobs.single.title, 'Oferta QA desde API');
      expect(
        () => CandidateSummaryModel.parse({...dashboardData(), 'metrics': {}}),
        throwsFormatException,
      );
    },
  );

  test(
    'recuperación respeta contratos y propaga enlace inválido sin exponer token',
    () async {
      final api = WorkNetApi(
        client: MockClient((request) async {
          final data = jsonDecode(request.body);
          if (request.url.path.endsWith('/request/')) {
            expect(data, {'email': 'qa@example.com'});
            return jsonResponse({
              'message': 'Si el correo está registrado, recibirás un enlace.',
            });
          }
          expect(data, {
            'uid': 'MQ',
            'token': 'qa-link',
            'new_password': 'Nueva!2026',
            'new_password_confirm': 'Nueva!2026',
          });
          return jsonResponse({
            'errors': {
              'token': ['El enlace es inválido o ha expirado.'],
            },
          }, 400);
        }),
      );
      addTearDown(api.close);
      await api.request(
        'password-recovery/request/',
        data: {'email': 'qa@example.com'},
      );
      await expectLater(
        api.request(
          'password-recovery/confirm/',
          data: {
            'uid': 'MQ',
            'token': 'qa-link',
            'new_password': 'Nueva!2026',
            'new_password_confirm': 'Nueva!2026',
          },
        ),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            contains('ha expirado'),
          ),
        ),
      );
    },
  );

  test(
    'error SMTP o HTML de backend no se presenta como envío exitoso',
    () async {
      final api = WorkNetApi(
        client: MockClient(
          (_) async => http.Response('SMTP_PRIVATE_TRACE', 500),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.request(
          'password-recovery/request/',
          data: {'email': 'qa@example.com'},
        ),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains('No pudimos enviar'), isNot(contains('PRIVATE'))),
          ),
        ),
      );
    },
  );
}
