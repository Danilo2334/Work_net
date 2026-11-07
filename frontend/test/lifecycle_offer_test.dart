import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/offers/data/offer_repository.dart';
import 'package:worknet/features/offers/presentation/active_offers_page.dart';
import 'edit_offer_test.dart' show offer;
import 'publish_offer_test.dart' show companySession;
import 'support/access_fakes.dart';

Map<String, dynamic> listing(Map<String, dynamic> stored) => {
  'count': 1,
  'next_page': null,
  'previous_page': null,
  'offers': [stored],
};

Future<void> press(WidgetTester t, String text) async {
  final target = find.text(text).last;
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  await t.tap(target);
  await t.pumpAndSettle();
}

void main() {
  test(
    'preserved offers and transitions authenticate, validate identity and state',
    () async {
      final api = WorkNetApi(
        client: MockClient((r) async {
          expect(r.headers['Authorization'], 'Token qa');
          if (r.method == 'POST') {
            expect(r.url.path, '/api/company/offers/7/transition/');
            expect(jsonDecode(r.body), {'action': 'archive', 'confirm': true});
            return jsonResponse({
              'offer': {...offer(), 'status': 'archived'},
            });
          }
          expect(r.url.queryParameters['page'], '2');
          return jsonResponse(listing({...offer(), 'status': 'closed'}));
        }),
      );
      addTearDown(api.close);
      final repo = HttpOfferRepository(api);
      expect(
        (await repo.preserved('qa', page: 2)).offers.single.status,
        'closed',
      );
      expect(
        (await repo.transition('qa', 7, archive: true)).status,
        'archived',
      );
      for (final wrong in [
        {...offer(), 'id': 8, 'status': 'closed'},
        offer(),
      ]) {
        final bad = WorkNetApi(
          client: MockClient((_) async => jsonResponse({'offer': wrong})),
        );
        await expectLater(
          HttpOfferRepository(bad).transition('qa', 7, archive: false),
          throwsA(isA<ApiFailure>()),
        );
        bad.close();
      }
    },
  );

  testWidgets(
    'archive cancellation makes no write; confirmed archive reloads preserved information without edit',
    (t) async {
      var stored = offer();
      var posts = 0;
      final api = WorkNetApi(
        client: MockClient((r) async {
          if (r.method == 'POST') {
            posts++;
            stored = {...stored, 'status': 'archived'};
            return jsonResponse({'offer': stored});
          }
          if (r.url.path.endsWith('/active/') &&
              stored['status'] != 'published') {
            return jsonResponse({
              'count': 0,
              'offers': [],
              'next_page': null,
              'previous_page': null,
            });
          }
          return jsonResponse(listing(stored));
        }),
      );
      addTearDown(api.close);
      final repo = HttpOfferRepository(api);
      await t.pumpWidget(
        MaterialApp(
          home: ActiveOffersPage(
            session: await companySession(),
            repository: repo,
            lifecycle: repo,
          ),
        ),
      );
      await t.pumpAndSettle();
      await press(t, 'Archivar oferta');
      expect(
        find.textContaining('postulaciones existentes se conservarán'),
        findsOneWidget,
      );
      await press(t, 'Cancelar');
      expect(posts, 0);
      expect(find.text('Editar oferta'), findsOneWidget);
      await press(t, 'Archivar oferta');
      await press(t, 'Confirmar archivado');
      expect(posts, 1);
      expect(find.text('Oferta archivada correctamente.'), findsOneWidget);
      await press(t, 'Ver ofertas conservadas');
      expect(find.text('Estado: Archivada'), findsOneWidget);
      expect(find.text('Descripción inicial'), findsOneWidget);
      expect(find.text('Editar oferta'), findsNothing);
      expect(find.text('Archivar oferta'), findsNothing);
    },
  );

  testWidgets(
    'network and server errors retain the offer and require a fresh confirmation; success follows retry',
    (t) async {
      var posts = 0;
      final api = WorkNetApi(
        client: MockClient((r) async {
          if (r.method == 'POST') {
            posts++;
            if (posts == 1) throw http.ClientException('QA offline');
            if (posts == 2) return jsonResponse({'detail': 'QA'}, 503);
            if (posts == 3) {
              return jsonResponse({'detail': 'Estado QA rechazado.'}, 409);
            }
            return jsonResponse({
              'offer': {...offer(), 'status': 'closed'},
            });
          }
          return jsonResponse(listing(offer()));
        }),
      );
      addTearDown(api.close);
      final repo = HttpOfferRepository(api);
      await t.pumpWidget(
        MaterialApp(
          home: ActiveOffersPage(
            session: await companySession(),
            repository: repo,
            lifecycle: repo,
          ),
        ),
      );
      await t.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await press(t, 'Cerrar oferta');
        await press(t, 'Confirmar cierre');
        expect(find.text('Título inicial'), findsOneWidget);
        expect(find.text('Oferta cerrada correctamente.'), findsNothing);
        expect(
          find.textContaining('comprobar el estado antes'),
          findsOneWidget,
        );
      }
      await press(t, 'Cerrar oferta');
      await press(t, 'Confirmar cierre');
      expect(posts, 4);
      expect(find.text('Oferta cerrada correctamente.'), findsOneWidget);
    },
  );

  testWidgets('401 during transition expires session without success', (
    t,
  ) async {
    final api = WorkNetApi(
      client: MockClient(
        (r) async => r.method == 'POST'
            ? jsonResponse({'detail': 'QA vencida'}, 401)
            : jsonResponse(listing(offer())),
      ),
    );
    addTearDown(api.close);
    final repo = HttpOfferRepository(api);
    final session = await companySession();
    await t.pumpWidget(
      MaterialApp(
        home: ActiveOffersPage(
          session: session,
          repository: repo,
          lifecycle: repo,
        ),
      ),
    );
    await t.pumpAndSettle();
    await press(t, 'Cerrar oferta');
    await press(t, 'Confirmar cierre');
    expect(session.session, isNull);
    expect(find.text('Oferta cerrada correctamente.'), findsNothing);
  });
}
