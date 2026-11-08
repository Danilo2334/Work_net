import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/dashboard/domain/candidate_summary.dart';
import 'package:worknet/features/dashboard/presentation/candidate_dashboard_page.dart';
import 'package:worknet/features/offers/data/favorites_repository.dart';
import 'package:worknet/features/offers/domain/favorites.dart';
import 'package:worknet/features/offers/domain/search.dart';
import 'package:worknet/features/offers/presentation/offer_search_page.dart';
import 'package:worknet/features/offers/presentation/saved_offers_page.dart';
import 'offer_search_test.dart' show candidateSession;
import 'support/access_fakes.dart';

SearchOffer summary(int id, {bool saved = true}) => SearchOffer(
  id: id,
  title: 'Oferta QA $id',
  companyName: 'Empresa QA',
  location: 'Pasto',
  contractType: 'Fijo',
  category: 'Tecnología',
  salary: null,
  publishedAt: DateTime.utc(2026, 11, 8),
  isSaved: saved,
);
SavedOfferEntry entry(int id, {String state = 'closed'}) => SavedOfferEntry(
  offer: summary(id),
  status: state,
  availability: state == 'published' ? 'active' : state,
  savedAt: DateTime.utc(2026, 11, 8),
);

class FavoritesFake implements SavedOffersRepository {
  final entries = <int, SavedOfferEntry>{};
  final pages = <int>[];
  final mutations = <(int, bool)>[];
  ApiFailure? loadFailure, saveFailure;
  Completer<SavedOffers>? pending;
  @override
  Future<SavedOffers> load(String token, {int page = 1}) async {
    pages.add(page);
    if (loadFailure case final e?) throw e;
    if (pending != null) return pending!.future;
    final rows = entries.values.toList()
      ..sort((a, b) => b.offer.id.compareTo(a.offer.id));
    final count = rows.length, total = (count / 10).ceil();
    return SavedOffers(
      offers: rows.skip((page - 1) * 10).take(10).toList(),
      count: count,
      page: page,
      totalPages: total,
      nextPage: page < total ? page + 1 : null,
      previousPage: page > 1 ? page - 1 : null,
    );
  }

  @override
  Future<bool> setSaved(String token, int id, bool saved) async {
    mutations.add((id, saved));
    if (saveFailure case final e?) throw e;
    if (saved) {
      entries[id] = entry(id, state: 'published');
    } else {
      entries.remove(id);
    }
    return saved;
  }
}

class SearchWithFavorites implements OfferSearchRepository {
  SearchWithFavorites(this.favorites);
  final FavoritesFake favorites;
  final calls = <Map<String, String>>[];
  @override
  Future<OfferSearchResult> search(
    String token,
    OfferSearchQuery query, {
    int page = 1,
  }) async {
    calls.add(query.parameters(page));
    return OfferSearchResult(
      offers: [summary(7, saved: favorites.entries.containsKey(7))],
      count: 1,
      page: 1,
      totalPages: 1,
      nextPage: null,
      previousPage: null,
      categories: ['Tecnología'],
      contractTypes: ['Fijo'],
    );
  }
}

class DashboardWithFavorites implements CandidateDashboardRepository {
  DashboardWithFavorites(this.favorites);
  final FavoritesFake favorites;
  @override
  Future<CandidateSummary> load(String token) async => CandidateSummary(
    name: 'Candidato QA',
    percentage: 17,
    applications: 0,
    saved: favorites.entries.length,
    notifications: 0,
    jobs: [
      JobPreview(
        id: 7,
        title: 'Oferta QA 7',
        companyName: 'Empresa QA',
        location: 'Pasto',
        contractType: 'Fijo',
        isSaved: favorites.entries.containsKey(7),
      ),
    ],
  );
}

Map<String, dynamic> responseRow() => {
  'id': 7,
  'title': 'Oferta QA',
  'company_name': 'Empresa QA',
  'location': 'Pasto',
  'contract_type': 'Fijo',
  'category': 'Tecnología',
  'salary': null,
  'published_at': null,
  'status': 'published',
  'availability': 'unavailable',
  'is_active': false,
  'is_saved': true,
  'saved_at': '2026-11-08T12:00:00Z',
};
Map<String, dynamic> savedBody(Map<String, dynamic> row) => {
  'count': 1,
  'page': 1,
  'page_size': 10,
  'total_pages': 1,
  'next_page': null,
  'previous_page': null,
  'offers': [row],
};
Future<void> tapText(WidgetTester t, String text) async {
  final f = find.text(text);
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  test(
    'HTTP PUT/DELETE use membership path, session header and no candidate body',
    () async {
      final calls = <String>[];
      final api = WorkNetApi(
        client: MockClient((r) async {
          calls.add(r.method);
          expect(r.url.path, '/api/offers/7/saved/');
          expect(r.url.query, '');
          expect(r.headers['Authorization'], 'Token local');
          expect(r.body, '');
          return jsonResponse({'offer_id': 7, 'is_saved': r.method == 'PUT'});
        }),
      );
      addTearDown(api.close);
      final repo = HttpSavedOffersRepository(api);
      expect(await repo.setSaved('local', 7, true), true);
      expect(await repo.setSaved('local', 7, true), true);
      expect(await repo.setSaved('local', 7, false), false);
      expect(calls, ['PUT', 'PUT', 'DELETE']);
    },
  );
  test(
    'saved contract handles unavailable publication and rejects contradictory states',
    () async {
      final row = responseRow();
      final api = WorkNetApi(
        client: MockClient((_) async => jsonResponse(savedBody(row))),
      );
      addTearDown(api.close);
      final repo = HttpSavedOffersRepository(api),
          first = await HttpSavedOffersRepository(api).load('local');
      expect(first.offers.single.statusLabel, 'No disponible');
      expect(first.offers.single.offer.publishedAt, null);
      row['status'] = 'closed';
      row['availability'] = 'active';
      row['is_active'] = true;
      await expectLater(repo.load('local'), throwsA(isA<ApiFailure>()));
      row['availability'] = 'closed';
      row['is_active'] = false;
      row['is_saved'] = false;
      await expectLater(repo.load('local'), throwsA(isA<ApiFailure>()));
    },
  );
  test(
    'mutation response must confirm the same identity and desired state',
    () async {
      for (final body in [
        {'offer_id': 8, 'is_saved': true},
        {'offer_id': 7, 'is_saved': 'true'},
        <String, dynamic>{},
      ]) {
        final api = WorkNetApi(
          client: MockClient((_) async => jsonResponse(body)),
        );
        await expectLater(
          HttpSavedOffersRepository(api).setSaved('local', 7, true),
          throwsA(isA<ApiFailure>()),
        );
        api.close();
      }
    },
  );
  testWidgets(
    'search → saved → remove → search refreshes state and keeps the query',
    (t) async {
      final session = await candidateSession(),
          favorites = FavoritesFake();
      final linked = SearchWithFavorites(favorites);
      final router = GoRouter(
        initialLocation: '/offers/search',
        routes: [
          GoRoute(
            path: '/offers/search',
            builder: (_, _) => OfferSearchPage(
              session: session,
              repository: linked,
              favorites: favorites,
            ),
          ),
          GoRoute(
            path: '/offers/saved',
            builder: (_, _) =>
                SavedOffersPage(session: session, repository: favorites),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('search_q')), 'Python');
      await tapText(t, 'Buscar');
      await tapText(t, 'Guardar oferta');
      expect(favorites.mutations, [(7, true)]);
      expect(find.text('Quitar de Guardados'), findsOneWidget);
      await tapText(t, 'Guardados');
      expect(find.text('1 ofertas guardadas'), findsOneWidget);
      await tapText(t, 'Quitar de Guardados');
      expect(find.text('0 ofertas guardadas'), findsOneWidget);
      await tapText(t, 'Volver al buscador');
      expect(find.text('Guardar oferta'), findsOneWidget);
      expect(linked.calls.last['q'], 'Python');
      expect(find.text('Oferta guardada.'), findsNothing);
    },
  );
  testWidgets(
    'inactive favorite can be removed on mobile without losing its status label',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final session = await candidateSession(),
          favorites = FavoritesFake()..entries[7] = entry(7);
      await t.pumpWidget(
        MaterialApp(
          home: SavedOffersPage(session: session, repository: favorites),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Estado: Cerrada'), findsOneWidget);
      await tapText(t, 'Quitar de Guardados');
      expect(favorites.mutations, [(7, false)]);
      expect(find.textContaining('Todavía no tienes'), findsOneWidget);
      expect(t.takeException(), null);
    },
  );
  testWidgets(
    'loading, retry and unconfirmed removal preserve the authoritative list',
    (t) async {
      final session = await candidateSession(),
          favorites = FavoritesFake()..pending = Completer<SavedOffers>();
      await t.pumpWidget(
        MaterialApp(
          home: SavedOffersPage(session: session, repository: favorites),
        ),
      );
      await t.pump();
      expect(find.text('Cargando Guardados…'), findsOneWidget);
      favorites.pending!.completeError(const ApiFailure('Fallo de red QA'));
      favorites.pending = null;
      await t.pumpAndSettle();
      expect(find.text('Fallo de red QA'), findsOneWidget);
      favorites.entries[7] = entry(7);
      await tapText(t, 'Reintentar');
      favorites.saveFailure = const ApiFailure('Respuesta no confirmada QA');
      await tapText(t, 'Quitar de Guardados');
      expect(favorites.entries.length, 1);
      expect(find.textContaining('Respuesta no confirmada QA'), findsOneWidget);
      favorites.saveFailure = null;
      await tapText(t, 'Reintentar');
      expect(find.text('Estado: Cerrada'), findsOneWidget);
    },
  );
  testWidgets(
    'removing the last row on page two returns to the preceding page',
    (t) async {
      final session = await candidateSession(), favorites = FavoritesFake();
      for (var i = 1; i <= 11; i++) {
        favorites.entries[i] = entry(i);
      }
      await t.pumpWidget(
        MaterialApp(
          home: SavedOffersPage(session: session, repository: favorites),
        ),
      );
      await t.pumpAndSettle();
      await tapText(t, 'Siguiente');
      expect(find.text('Página 2 de 2'), findsOneWidget);
      await tapText(t, 'Quitar de Guardados');
      expect(favorites.pages.last, 1);
      expect(find.text('Página 1 de 1'), findsOneWidget);
      expect(favorites.entries.length, 10);
    },
  );
  testWidgets(
    'dashboard recent offer saves through the same repository and reloads its count',
    (t) async {
      final session = await candidateSession(), favorites = FavoritesFake();
      await t.pumpWidget(
        MaterialApp(
          home: CandidateDashboardPage(
            controller: session,
            repository: DashboardWithFavorites(favorites),
            favorites: favorites,
          ),
        ),
      );
      await t.pumpAndSettle();
      await tapText(t, 'Guardar oferta');
      expect(favorites.mutations, [(7, true)]);
      expect(find.text('Quitar de Guardados'), findsOneWidget);
      await tapText(t, 'Quitar de Guardados');
      expect(favorites.entries, isEmpty);
    },
  );
}
