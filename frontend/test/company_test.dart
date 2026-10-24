import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/app.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/access/data/access_repository.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/company/data/company_repository.dart';
import 'support/access_fakes.dart';
import 'support/company_fakes.dart';

Future<void> tap(WidgetTester t, Finder f) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> start(
  WidgetTester t,
  Future<http.Response> Function(http.Request) handler, {
  String role = 'empresa',
  String path = '/company',
  bool authenticated = true,
  String? companyState,
}) async {
  final api = WorkNetApi(client: MockClient(handler));
  addTearDown(api.close);
  final data = sessionData(role: role);
  if (companyState != null) data['user']['company_state'] = companyState;
  final store = MemorySessionStore()
    ..value = authenticated ? jsonEncode(data) : null;
  await t.pumpWidget(
    WorkNetApp(
      key: UniqueKey(),
      api: api,
      sessionStore: store,
      initialLocation: path,
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'empresa pendiente completa guarda y envía datos reales sin cambiar su estado localmente',
    (t) async {
      var sent = false;
      var writes = 0;
      await start(t, (r) async {
        expect(r.headers['Authorization'], 'Token qa-token');
        if (r.method == 'PATCH') {
          writes++;
          expect(jsonDecode(r.body)['tax_id'], '900111222-3');
        }
        if (r.url.path.endsWith('/submit/')) {
          sent = true;
        }
        return jsonResponse({'company': companyData(submitted: sent)});
      });
      expect(find.text('Estado: Pendiente'), findsOneWidget);
      await tap(t, find.byKey(const Key('company_submit')));
      expect(writes, 1);
      expect(sent, true);
      expect(
        find.text('Tu información está siendo revisada por un administrador.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('company_submit')), findsNothing);
    },
  );
  testWidgets('empresa rechazada ve el motivo y puede corregir y reenviar', (
    t,
  ) async {
    var state = 'rejected';
    await start(t, (r) async {
      if (r.url.path.endsWith('/submit/')) state = 'pending';
      return jsonResponse({
        'company': companyData(state: state, submitted: state == 'pending'),
      });
    });
    expect(
      find.text('Motivo del rechazo: Corrige la razón social.'),
      findsOneWidget,
    );
    await t.enterText(
      find.byKey(const Key('company_name')),
      'Empresa corregida QA',
    );
    await tap(t, find.byKey(const Key('company_submit')));
    expect(find.text('Estado: Pendiente'), findsOneWidget);
  });
  testWidgets(
    'campos empresariales obligatorios bloquean envío y error Django se muestra',
    (t) async {
      var writes = 0;
      await start(t, (r) async {
        if (r.method == 'PATCH') {
          writes++;
          return jsonResponse({
            'tax_id': ['Este NIT ya está asociado a otra cuenta empresarial.'],
          }, 400);
        }
        return jsonResponse({'company': companyData()});
      });
      await t.enterText(find.byKey(const Key('company_name')), '');
      await tap(t, find.byKey(const Key('company_submit')));
      expect(writes, 0);
      expect(find.text('Completa este campo.'), findsOneWidget);
      await t.enterText(find.byKey(const Key('company_name')), 'Empresa QA');
      await tap(t, find.byKey(const Key('company_submit')));
      expect(writes, 1);
      expect(
        find.text('Este NIT ya está asociado a otra cuenta empresarial.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'empresa aprobada accede al dashboard por el estado recibido al iniciar sesión',
    (t) async {
      final calls = <String>[];
      await start(
        t,
        (r) async {
          calls.add(r.url.path);
          return jsonResponse(companySummary());
        },
        path: '/login',
        companyState: 'approved',
      );
      expect(find.text('Dashboard de empresa'), findsOneWidget);
      expect(find.text('Ofertas activas: 2'), findsOneWidget);
      expect(
        find.text('Todavía no has recibido postulaciones.'),
        findsOneWidget,
      );
      expect(calls, ['/api/dashboard/company/']);
    },
  );
  testWidgets(
    'dashboard empresarial maneja error reintento y datos cero sin inventarlos',
    (t) async {
      var attempt = 0;
      await start(
        t,
        (_) async => ++attempt == 1
            ? http.Response('error', 500)
            : jsonResponse({
                ...companySummary(),
                'metrics': {
                  'active_offers': 0,
                  'closed_offers': 0,
                  'applications': 0,
                },
              }),
        path: '/company-dashboard',
        companyState: 'approved',
      );
      expect(
        find.textContaining('El servicio no está disponible'),
        findsOneWidget,
      );
      await tap(t, find.text('Reintentar'));
      expect(find.text('Ofertas activas: 0'), findsOneWidget);
    },
  );
  testWidgets(
    'administración usa conteos reales y abre solicitudes pendientes',
    (t) async {
      await start(
        t,
        (r) async => jsonResponse(
          r.url.path.contains('/admin/companies/')
              ? {
                  'companies': [companyData(submitted: true)],
                  'count': 1,
                  'page': 1,
                  'has_next': false,
                }
              : adminSummary(),
        ),
        role: 'admin',
        path: '/admin-dashboard',
      );
      expect(find.text('Candidatos registrados: 4'), findsOneWidget);
      expect(find.text('Solicitudes pendientes: 1'), findsOneWidget);
      await tap(t, find.byKey(const Key('open_company_reviews')));
      expect(find.text('NIT: 900111222-3'), findsOneWidget);
      expect(find.byKey(const Key('approve_company_1')), findsOneWidget);
    },
  );
  testWidgets(
    'rechazo exige motivo y envía decisión con versión sin permitir autoaprobación',
    (t) async {
      var reviews = 0;
      await start(
        t,
        (r) async {
          if (r.method == 'POST') {
            reviews++;
            expect(jsonDecode(r.body), {
              'decision': 'rejected',
              'version': 2,
              'reason': 'Corregir ubicación.',
            });
            return jsonResponse({'message': 'Decisión registrada.'});
          }
          return jsonResponse({
            'companies': reviews == 0 ? [companyData(submitted: true)] : [],
            'count': reviews == 0 ? 1 : 0,
            'page': 1,
            'has_next': false,
          });
        },
        role: 'admin',
        path: '/company-reviews',
      );
      await tap(t, find.byKey(const Key('reject_company_1')));
      await tap(t, find.byKey(const Key('confirm_company_review')));
      expect(reviews, 0);
      expect(find.text('Escribe el motivo del rechazo.'), findsOneWidget);
      await t.enterText(
        find.byKey(const Key('review_reason')),
        'Corregir ubicación.',
      );
      await tap(t, find.byKey(const Key('confirm_company_review')));
      expect(reviews, 1);
      expect(
        find.text('Solicitud rechazada y motivo registrado.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('aprobar pide confirmación y cancelar no modifica la solicitud', (
    t,
  ) async {
    var writes = 0;
    await start(
      t,
      (r) async {
        if (r.method == 'POST') writes++;
        return jsonResponse({
          'companies': [companyData(submitted: true)],
          'count': 1,
          'page': 1,
          'has_next': false,
        });
      },
      role: 'admin',
      path: '/company-reviews',
    );
    await tap(t, find.byKey(const Key('approve_company_1')));
    await tap(t, find.text('Cancelar'));
    expect(writes, 0);
    expect(find.byKey(const Key('approve_company_1')), findsOneWidget);
  });
  testWidgets(
    'sesión ausente o rol incorrecto no consulta solicitudes administrativas',
    (t) async {
      var adminCalls = 0;
      await start(
        t,
        (r) async {
          if (r.url.path.contains('admin/')) adminCalls++;
          return jsonResponse({'company': companyData()});
        },
        path: '/company-reviews',
        authenticated: false,
      );
      expect(find.byKey(const Key('submit_login')), findsOneWidget);
      expect(adminCalls, 0);
      await start(t, (r) async {
        if (r.url.path.contains('admin/')) adminCalls++;
        return jsonResponse({'company': companyData()});
      }, path: '/company-reviews');
      expect(find.text('Tu empresa'), findsOneWidget);
      expect(adminCalls, 0);
    },
  );
  test(
    'logout fallido conserva opción de reintento y 401 confirma credencial inválida',
    () async {
      var offline = true;
      final api = WorkNetApi(
        client: MockClient((r) async {
          expect(r.url.path, '/api/logout/');
          if (offline) throw http.ClientException('sin red');
          return jsonResponse({'detail': 'Invalid token'}, 401);
        }),
      );
      addTearDown(api.close);
      final store = MemorySessionStore()..value = jsonEncode(sessionData());
      final session = SessionController(
        repository: HttpAccessRepository(api, store),
      );
      addTearDown(session.dispose);
      await session.restore();
      await expectLater(session.logout(), throwsA(isA<ApiFailure>()));
      expect(session.session, isNotNull);
      expect(store.value, isNotNull);
      offline = false;
      await session.logout();
      expect(session.session, isNull);
      expect(store.value, isNull);
    },
  );
  test(
    'resumen malformado se rechaza sin convertir datos faltantes a cero',
    () async {
      final api = WorkNetApi(
        client: MockClient(
          (_) async => jsonResponse({
            'metrics': {
              'active_offers': 1,
              'closed_offers': 0,
              'applications': 0,
            },
            'notifications': [],
          }),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        HttpCompanyRepository(api).companySummary('qa'),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
  for (final size in [const Size(390, 844), const Size(1440, 1000)]) {
    testWidgets('información revisión y dashboards sin overflow en $size', (
      t,
    ) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = size;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      await start(t, (_) async => jsonResponse({'company': companyData()}));
      expect(t.takeException(), isNull);
      await start(
        t,
        (_) async => jsonResponse(adminSummary()),
        role: 'admin',
        path: '/admin-dashboard',
      );
      expect(t.takeException(), isNull);
      await start(
        t,
        (_) async => jsonResponse({
          'companies': [companyData(submitted: true)],
          'count': 1,
          'page': 1,
          'has_next': false,
        }),
        role: 'admin',
        path: '/company-reviews',
      );
      await tap(t, find.byKey(const Key('reject_company_1')));
      expect(t.takeException(), isNull);
    });
  }
}
