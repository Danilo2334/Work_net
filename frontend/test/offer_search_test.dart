import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/access/data/access_repository.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/offers/data/search_repository.dart';
import 'package:worknet/features/offers/domain/search.dart';
import 'package:worknet/features/offers/presentation/offer_search_page.dart';
import 'support/access_fakes.dart';

class SearchFake implements OfferSearchRepository {
  final calls = <Map<String, String>>[];
  ApiFailure? failure;
  Completer<OfferSearchResult>? pending;
  @override
  Future<OfferSearchResult> search(
    String token,
    OfferSearchQuery query, {
    int page = 1,
  }) async {
    calls.add(query.parameters(page));
    if (failure case final e?) throw e;
    return pending?.future ??
        OfferSearchResult(
          offers: [
            SearchOffer(
              id: page,
              title: 'Oferta página $page',
              companyName: 'Empresa QA',
              location: 'Pasto',
              contractType: 'Fijo',
              category: 'Tecnología',
              salary: page == 1 ? '200.00' : null,
              publishedAt: DateTime.utc(2026, 11, 8),
            ),
          ],
          count: 11,
          page: page,
          totalPages: 2,
          nextPage: page == 1 ? 2 : null,
          previousPage: page == 2 ? 1 : null,
          categories: ['Tecnología'],
          contractTypes: ['Fijo'],
        );
  }
}

Future<SessionController> candidateSession() async {
  final api = WorkNetApi(
    client: MockClient((_) async => jsonResponse(sessionData())),
  );
  final session = SessionController(
    repository: HttpAccessRepository(api, MemorySessionStore()),
  );
  await session.login('qa@example.com', 'local', remember: false);
  return session;
}

Future<void> press(WidgetTester t, String label) async {
  final target =
      find.widgetWithText(OutlinedButton, label).evaluate().isNotEmpty
      ? find.widgetWithText(OutlinedButton, label)
      : find.widgetWithText(FilledButton, label);
  await t.ensureVisible(target);
  await t.tap(target);
  await t.pumpAndSettle();
}

void main() {
  test(
    'HTTP GET encodes filters, keeps token private and parses nullable salaries',
    () async {
      final api = WorkNetApi(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Token local');
          expect(request.url.path, '/api/offers/search/');
          expect(request.url.queryParameters, {
            'q': 'Python QA',
            'location': 'Bogotá',
            'salary_min': '0.50',
            'salary_max': '200',
            'category': 'Tecnología',
            'contract_type': 'Fijo',
            'sort': 'date',
            'page': '2',
            'page_size': '10',
          });
          expect(request.url.toString().contains('local'), false);
          return jsonResponse({
            'count': 11,
            'page': 2,
            'page_size': 10,
            'total_pages': 2,
            'next_page': null,
            'previous_page': 1,
            'categories': ['Tecnología'],
            'contract_types': ['Fijo'],
            'offers': [
              {
                'id': 20,
                'title': 'Python QA',
                'company_name': 'Empresa QA',
                'location': 'Bogotá',
                'category': 'Tecnología',
                'contract_type': 'Fijo',
                'salary': null,
                'published_at': '2026-11-08T10:00:00Z',
              },
            ],
          });
        }),
      );
      addTearDown(api.close);
      final result = await HttpOfferSearchRepository(api).search(
        'local',
        const OfferSearchQuery(
          q: 'Python QA',
          location: 'Bogotá',
          salaryMin: '0,50',
          salaryMax: '200',
          category: 'Tecnología',
          contractType: 'Fijo',
          sort: 'date',
        ),
        page: 2,
      );
      expect(result.offers.single.salary, null);
      expect(result.previousPage, 1);
    },
  );
  test('malformed successful responses become retryable failures', () async {
    for (final body in [
      <String, dynamic>{},
      {'count': -1},
      {'count': 0, 'page': 1, 'page_size': 0},
    ]) {
      final api = WorkNetApi(
        client: MockClient((_) async => jsonResponse(body)),
      );
      await expectLater(
        HttpOfferSearchRepository(
          api,
        ).search('local', const OfferSearchQuery()),
        throwsA(isA<ApiFailure>()),
      );
      api.close();
    }
  });
  testWidgets(
    'filters and order persist across pages, edits reset page and hide stale results',
    (t) async {
      t.view.physicalSize = const Size(1440, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = SearchFake(), session = await candidateSession();
      await t.pumpWidget(
        MaterialApp(
          home: OfferSearchPage(session: session, repository: repo),
        ),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('search_q')), 'Python');
      await t.enterText(find.byKey(const Key('search_location')), 'Pasto');
      expect(find.text('Oferta página 1'), findsNothing);
      await press(t, 'Buscar');
      expect(repo.calls.last['page'], '1');
      await press(t, 'Siguiente');
      expect(repo.calls.last, containsPair('page', '2'));
      expect(repo.calls.last, containsPair('q', 'Python'));
      expect(repo.calls.last, containsPair('location', 'Pasto'));
      expect(find.text('Salario no informado'), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('search_q')));
      await t.enterText(find.byKey(const Key('search_q')), 'Django');
      await press(t, 'Buscar');
      expect(repo.calls.last['page'], '1');
      expect(repo.calls.last['q'], 'Django');
      await press(t, 'Limpiar filtros');
      expect(repo.calls.last.containsKey('q'), false);
    },
  );
  testWidgets(
    'salary validation blocks bad range and mobile layout has no overflow',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = SearchFake(), session = await candidateSession();
      await t.pumpWidget(
        MaterialApp(
          home: OfferSearchPage(session: session, repository: repo),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('search_salary_min')));
      await t.enterText(find.byKey(const Key('search_salary_min')), '400');
      await t.ensureVisible(find.byKey(const Key('search_salary_max')));
      await t.enterText(find.byKey(const Key('search_salary_max')), '200');
      await press(t, 'Buscar');
      expect(repo.calls.length, 1);
      expect(
        find.text('El máximo debe ser mayor o igual al mínimo.'),
        findsOneWidget,
      );
      expect(t.takeException(), null);
    },
  );
  testWidgets('loading, network error, retry and real session expiration', (
    t,
  ) async {
    final repo = SearchFake()..pending = Completer<OfferSearchResult>(),
        session = await candidateSession();
    await t.pumpWidget(
      MaterialApp(
        home: OfferSearchPage(session: session, repository: repo),
      ),
    );
    await t.pump();
    expect(find.text('Buscando ofertas…'), findsOneWidget);
    repo.pending!.completeError(const ApiFailure('Sin conexión QA'));
    repo.pending = null;
    await t.pumpAndSettle();
    expect(find.text('Sin conexión QA'), findsOneWidget);
    await press(t, 'Reintentar');
    expect(find.text('Oferta página 1'), findsOneWidget);
    repo.failure = const ApiFailure('Sesión vencida', status: 401);
    await press(t, 'Buscar');
    expect(session.session, null);
  });
}
