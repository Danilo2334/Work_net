import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/access/data/access_repository.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/statistics/statistics_repository.dart';
import 'package:worknet/features/statistics/statistics_page.dart';
import 'package:worknet/features/applications/presentation/application_history_page.dart';
import 'applications_test.dart' show ApplicationsFake;
import 'package:worknet/features/applicants/presentation/applicants_page.dart';
import 'package:worknet/features/applicants/domain/applicant.dart';
import 'applicants_test.dart' show ApplicantsFake;
import 'support/access_fakes.dart';

Map<String, int> stateCounts({bool empty = false}) => {
  'submitted': empty ? 0 : 2,
  'in_review': empty ? 0 : 1,
  'accepted': empty ? 0 : 1,
  'rejected': empty ? 0 : 1,
  'other': 0,
};
Map<String, dynamic> statisticsJson({bool company = false}) => {
  'role': company ? 'empresa' : 'candidato',
  'scope': 'all_persisted_applications',
  'as_of': '2026-11-08T20:00:00Z',
  'applications_count': 5,
  'states': stateCounts(),
  if (company) ...{
    'active_offers_count': 1,
    'offers': {
      'count': 1,
      'page': 1,
      'page_size': 10,
      'total_pages': 1,
      'next_page': null,
      'previous_page': null,
      'rows': [
        {
          'id': 3,
          'title': 'Oferta QA',
          'status': 'published',
          'is_active': true,
          'applications_count': 5,
          'states': stateCounts(),
        },
      ],
    },
  },
};

class StatisticsFake implements StatisticsRepository {
  final calls = <({bool company, int page})>[];
  ApiFailure? failure;
  Completer<StatisticsSummary>? pending;
  bool empty = false;
  int total = 5;
  @override
  Future<StatisticsSummary> load(
    String token, {
    required bool company,
    int page = 1,
  }) async {
    calls.add((company: company, page: page));
    if (failure case final e?) throw e;
    return pending?.future ??
        StatisticsSummary(
          total: empty ? 0 : total,
          states: empty
              ? stateCounts(empty: true)
              : {...stateCounts(), 'submitted': total - 3},
          at: DateTime.utc(2026, 11, 8, 20),
          activeOffers: company ? (empty ? 0 : 1) : null,
          offers: company && !empty
              ? [
                  OfferStatistics(
                    page,
                    'Oferta página $page',
                    'closed',
                    false,
                    total,
                    {...stateCounts(), 'submitted': total - 3},
                  ),
                ]
              : [],
          page: page,
          pages: company && !empty ? 2 : 0,
          offerCount: company && !empty ? 11 : 0,
        );
  }
}

Future<SessionController> sessionFor({bool company = false}) async {
  final data = sessionData(role: company ? 'empresa' : 'candidato');
  if (company) (data['user'] as Map)['company_state'] = 'approved';
  final api = WorkNetApi(client: MockClient((_) async => jsonResponse(data)));
  final s = SessionController(
    repository: HttpAccessRepository(api, MemorySessionStore()),
  );
  await s.login('qa@example.com', 'local', remember: false);
  return s;
}

Future<SessionController> showStats(
  WidgetTester t,
  StatisticsFake r, {
  bool company = false,
  bool mobile = false,
}) async {
  t.view.physicalSize = mobile ? const Size(390, 844) : const Size(1440, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final s = await sessionFor(company: company);
  await t.pumpWidget(
    MaterialApp(
      home: StatisticsPage(key: UniqueKey(), session: s, repository: r),
    ),
  );
  return s;
}

Future<void> tap(WidgetTester t, String label) async {
  final target = find.text(label);
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
}

void main() {
  test(
    'HTTP usa el contrato por rol y valida agregados sin datos personales',
    () async {
      var company = false;
      final api = WorkNetApi(
        client: MockClient((r) async {
          expect(r.method, 'GET');
          expect(r.headers['Authorization'], 'Token qa-private');
          expect(
            r.url.path,
            company ? '/api/statistics/company/' : '/api/statistics/candidate/',
          );
          if (company) {
            expect(r.url.queryParameters, {'page': '1', 'page_size': '10'});
          }
          return jsonResponse(statisticsJson(company: company));
        }),
      );
      final repo = HttpStatisticsRepository(api);
      expect(
        (await repo.load('qa-private', company: false)).states['in_review'],
        1,
      );
      company = true;
      final d = await repo.load('qa-private', company: true);
      expect(d.offers.single.id, 3);
      expect(d.activeOffers, 1);
      expect(d.total, 5);
      api.close();
    },
  );
  test(
    'rechaza totales incoherentes roles ajenos y metadatos de página inválidos',
    () async {
      for (final mode in ['total', 'role', 'page', 'duplicate', 'negative']) {
        final body = statisticsJson(company: true);
        if (mode == 'total') body['applications_count'] = 4;
        if (mode == 'role') body['role'] = 'admin';
        if (mode == 'page') (body['offers'] as Map)['next_page'] = 2;
        if (mode == 'duplicate') {
          (body['offers'] as Map)['rows'] = [
            ...(body['offers'] as Map)['rows'] as List,
            ...(body['offers'] as Map)['rows'] as List,
          ];
        }
        if (mode == 'negative') (body['states'] as Map)['accepted'] = -1;
        final api = WorkNetApi(
          client: MockClient((_) async => jsonResponse(body)),
        );
        await expectLater(
          HttpStatisticsRepository(api).load('qa', company: true),
          throwsA(isA<ApiFailure>()),
        );
        api.close();
      }
    },
  );
  testWidgets(
    'carga y muestra estados candidato y refresca después de cambio',
    (t) async {
      final r = StatisticsFake()..pending = Completer<StatisticsSummary>();
      await showStats(t, r);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      r.pending!.complete(
        StatisticsSummary(
          total: 5,
          states: stateCounts(),
          at: DateTime.utc(2026, 11, 8),
        ),
      );
      r.pending = null;
      await t.pumpAndSettle();
      expect(find.text('Postulaciones realizadas: 5'), findsOneWidget);
      expect(find.text('En revisión: 1'), findsOneWidget);
      expect(find.text('Aceptadas: 1'), findsOneWidget);
      r.total = 6;
      await tap(t, 'Actualizar estadísticas');
      expect(find.text('Postulaciones realizadas: 6'), findsOneWidget);
    },
  );
  testWidgets(
    'empresa pagina ofertas conservando métricas globales y resetea al actualizar',
    (t) async {
      final r = StatisticsFake();
      await showStats(t, r, company: true);
      await t.pumpAndSettle();
      expect(find.text('Ofertas activas: 1'), findsOneWidget);
      await tap(t, 'Página siguiente');
      expect(r.calls.last.page, 2);
      expect(
        t.state<ScrollableState>(find.byType(Scrollable).first).position.pixels,
        0,
      );
      expect(find.text('Oferta página 2'), findsOneWidget);
      expect(find.text('Postulaciones recibidas: 5'), findsNWidgets(2));
      await tap(t, 'Actualizar estadísticas');
      expect(r.calls.last.page, 1);
    },
  );
  testWidgets('vacío móvil muestra ceros y no produce desbordamiento', (
    t,
  ) async {
    final r = StatisticsFake()..empty = true;
    await showStats(t, r, company: true, mobile: true);
    await t.pumpAndSettle();
    expect(find.text('Postulaciones recibidas: 0'), findsOneWidget);
    expect(find.text('Ofertas activas: 0'), findsOneWidget);
    await t.ensureVisible(find.text('Todavía no has creado ofertas.'));
    expect(t.takeException(), isNull);
    final bars = t.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bars.every((b) => b.value == 0), isTrue);
  });
  testWidgets('error recuperable no muestra datos y reintenta lectura', (
    t,
  ) async {
    final r = StatisticsFake()..failure = const ApiFailure('Fallo QA');
    await showStats(t, r);
    await t.pumpAndSettle();
    expect(find.text('Fallo QA'), findsOneWidget);
    expect(find.text('Postulaciones realizadas: 5'), findsNothing);
    r.failure = null;
    await tap(t, 'Reintentar');
    expect(find.text('Postulaciones realizadas: 5'), findsOneWidget);
  });
  testWidgets(
    '401 expira sesión y una respuesta tardía no repone estadísticas',
    (t) async {
      final r = StatisticsFake()..pending = Completer<StatisticsSummary>();
      final s = await showStats(t, r);
      await s.expire();
      r.pending!.complete(
        StatisticsSummary(
          total: 5,
          states: stateCounts(),
          at: DateTime.utc(2026, 11, 8),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Postulaciones realizadas: 5'), findsNothing);
      final other = StatisticsFake()
        ..failure = const ApiFailure('Sesión finalizada', status: 401);
      final s2 = await showStats(t, other);
      await t.pumpAndSettle();
      expect(s2.session, isNull);
    },
  );
  testWidgets('navega al historial y al volver consulta el dato actualizado', (
    t,
  ) async {
    final r = StatisticsFake(), s = await sessionFor();
    final router = GoRouter(
      initialLocation: '/statistics',
      routes: [
        GoRoute(
          path: '/statistics',
          builder: (_, _) => StatisticsPage(session: s, repository: r),
        ),
        GoRoute(
          path: '/applications',
          builder: (context, state) => ApplicationHistoryPage(
            session: s,
            repository: ApplicationsFake(),
            returnToStatistics: state.extra == 'statistics',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    await tap(t, 'Consultar mi historial');
    r.total = 6;
    await tap(t, 'Volver a estadísticas');
    expect(find.text('Postulaciones realizadas: 6'), findsOneWidget);
    expect(r.calls.length, 2);
  });
  testWidgets(
    'postulantes conserva retorno a estadísticas después de paginar',
    (t) async {
      t.view.physicalSize = const Size(1440, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = StatisticsFake(),
          s = await sessionFor(company: true),
          applicants = ApplicantsFake();
      final observer = RouteObserver<ModalRoute<dynamic>>();
      final router = GoRouter(
        initialLocation: '/statistics',
        observers: [observer],
        routes: [
          GoRoute(
            path: '/statistics',
            builder: (_, _) => StatisticsPage(
              session: s,
              repository: r,
              routeObserver: observer,
            ),
          ),
          GoRoute(
            path: '/company/offers/:id/applicants',
            builder: (_, state) => ApplicantsPage(
              key: ValueKey(state.uri),
              session: s,
              repository: applicants,
              offerId: 1,
              query: ApplicantQuery.fromUri(state.uri),
              returnToStatistics: state.extra == 'statistics',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      await tap(t, 'Consultar postulantes de Oferta página 1');
      await tap(t, 'Siguiente');
      expect(applicants.calls.last.page, 2);
      r.total = 6;
      await tap(t, 'Volver a estadísticas');
      expect(find.text('Postulaciones recibidas: 6'), findsNWidgets(2));
    },
  );
}
