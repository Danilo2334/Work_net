import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/offers/data/offer_repository.dart';
import 'package:worknet/features/offers/presentation/publish_offer_page.dart';
import 'publish_offer_test.dart' show companySession, fill, submit;
import 'support/access_fakes.dart';

Map<String, dynamic> offer() => {
  'id': 7,
  'title': 'Título inicial',
  'description': 'Descripción inicial',
  'requirements': 'Requisitos iniciales',
  'salary': '500.00',
  'location': 'Lugar QA',
  'category': 'Tecnología',
  'contract_type': 'Indefinido',
  'status': 'published',
};
Map<String, dynamic> catalog() => {
  'categories': ['Tecnología', 'Educación'],
  'contract_types': ['Indefinido', 'Fijo'],
};

void main() {
  test(
    'authenticated list, detail and PATCH preserve the offer ID and send only editable fields',
    () async {
      var stored = offer();
      final api = WorkNetApi(
        client: MockClient((r) async {
          expect(r.headers['Authorization'], 'Token local');
          if (r.url.path.endsWith('/active/')) {
            expect(r.url.queryParameters['page'], '2');
            return jsonResponse({
              'count': 21,
              'next_page': null,
              'previous_page': 1,
              'offers': [stored],
            });
          }
          expect(r.url.path, '/api/company/offers/7/');
          if (r.method == 'PATCH') {
            final changes = jsonDecode(r.body) as Map<String, dynamic>;
            expect(changes.length, 7);
            expect(changes.containsKey('id'), false);
            expect(changes.containsKey('company'), false);
            stored = {...stored, ...changes};
          }
          return jsonResponse({'offer': stored});
        }),
      );
      addTearDown(api.close);
      final repo = HttpOfferRepository(api);
      expect((await repo.active('local', page: 2)).previousPage, 1);
      final loaded = await repo.read('local', 7);
      expect(loaded.draft.title, 'Título inicial');
      final saved = await repo.update('local', 7, loaded.draft);
      expect(saved.id, 7);
      expect(
        (await repo.read('local', 7)).draft.toJson(),
        saved.draft.toJson(),
      );
    },
  );
  test(
    'wrong identities and malformed list/detail are recoverable errors',
    () async {
      for (final body in [
        <String, dynamic>{},
        {
          'offer': {...offer(), 'id': 8},
        },
        {
          'offer': {...offer(), 'salary': 5},
        },
      ]) {
        final api = WorkNetApi(
          client: MockClient((_) async => jsonResponse(body)),
        );
        await expectLater(
          HttpOfferRepository(api).read('local', 7),
          throwsA(isA<ApiFailure>()),
        );
        api.close();
      }
      final api = WorkNetApi(
        client: MockClient(
          (_) async => jsonResponse({
            'count': 1,
            'offers': [
              {'id': 7},
            ],
          }),
        ),
      );
      await expectLater(
        HttpOfferRepository(api).active('local'),
        throwsA(isA<ApiFailure>()),
      );
      api.close();
    },
  );
  testWidgets(
    'preloads seven fields then confirms an update without publishing a new offer',
    (t) async {
      var patches = 0;
      final api = WorkNetApi(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/7/')) {
            if (r.method == 'PATCH') {
              patches++;
              return jsonResponse({
                'offer': {
                  ...offer(),
                  ...jsonDecode(r.body) as Map<String, dynamic>,
                },
              });
            }
            return jsonResponse({'offer': offer()});
          }
          return jsonResponse(catalog());
        }),
      );
      addTearDown(api.close);
      final repo = HttpOfferRepository(api);
      await t.pumpWidget(
        MaterialApp(
          home: PublishOfferPage(
            session: await companySession(),
            repository: repo,
            editingRepository: repo,
            offerId: 7,
          ),
        ),
      );
      await t.pumpAndSettle();
      for (final key in [
        'title',
        'description',
        'requirements',
        'salary',
        'location',
      ]) {
        expect(
          t
              .widget<TextFormField>(find.byKey(Key('offer_$key')))
              .controller!
              .text,
          offer()[key],
        );
      }
      expect(find.text('Tecnología'), findsOneWidget);
      expect(find.text('Indefinido'), findsOneWidget);
      await fill(t);
      await submit(t);
      expect(patches, 1);
      expect(find.text('Cambios guardados correctamente.'), findsOneWidget);
      expect(find.text('Publicar oferta'), findsNothing);
    },
  );
  testWidgets('invalid salary prevents an update', (t) async {
    var patches = 0;
    final api = WorkNetApi(
      client: MockClient((r) async {
        if (r.method == 'PATCH') patches++;
        return jsonResponse(
          r.url.path.endsWith('/7/') ? {'offer': offer()} : catalog(),
        );
      }),
    );
    addTearDown(api.close);
    final repo = HttpOfferRepository(api);
    await t.pumpWidget(
      MaterialApp(
        home: PublishOfferPage(
          session: await companySession(),
          repository: repo,
          editingRepository: repo,
          offerId: 7,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('offer_salary')), '-1');
    await submit(t);
    expect(patches, 0);
    expect(
      find.textContaining('Escribe un salario no negativo'),
      findsOneWidget,
    );
  });
  testWidgets('network, 503 and 400 preserve edits for retry', (t) async {
    var patches = 0;
    final api = WorkNetApi(
      client: MockClient((r) async {
        if (r.method == 'PATCH') {
          patches++;
          if (patches == 1) throw http.ClientException('offline');
          if (patches == 2) return jsonResponse({'detail': 'QA'}, 503);
          if (patches == 3) {
            return jsonResponse({
              'salary': ['Revisa el salario QA.'],
            }, 400);
          }
          return jsonResponse({
            'offer': {
              ...offer(),
              ...jsonDecode(r.body) as Map<String, dynamic>,
            },
          });
        }
        return jsonResponse(
          r.url.path.endsWith('/7/') ? {'offer': offer()} : catalog(),
        );
      }),
    );
    addTearDown(api.close);
    final repo = HttpOfferRepository(api);
    await t.pumpWidget(
      MaterialApp(
        home: PublishOfferPage(
          session: await companySession(),
          repository: repo,
          editingRepository: repo,
          offerId: 7,
        ),
      ),
    );
    await t.pumpAndSettle();
    await fill(t);
    for (var i = 0; i < 3; i++) {
      await submit(t);
      expect(find.text('Cambios guardados correctamente.'), findsNothing);
      expect(
        t
            .widget<TextFormField>(find.byKey(const Key('offer_title')))
            .controller!
            .text,
        'Oferta QA',
      );
    }
    await submit(t);
    expect(patches, 4);
    expect(find.text('Cambios guardados correctamente.'), findsOneWidget);
  });
  testWidgets('401 expires the current session without confirming a save', (
    t,
  ) async {
    final api = WorkNetApi(
      client: MockClient((r) async {
        if (r.method == 'PATCH') {
          return jsonResponse({'detail': 'Sesión vencida'}, 401);
        }
        return jsonResponse(
          r.url.path.endsWith('/7/') ? {'offer': offer()} : catalog(),
        );
      }),
    );
    addTearDown(api.close);
    final repo = HttpOfferRepository(api);
    final session = await companySession();
    await t.pumpWidget(
      MaterialApp(
        home: PublishOfferPage(
          session: session,
          repository: repo,
          editingRepository: repo,
          offerId: 7,
        ),
      ),
    );
    await t.pumpAndSettle();
    await submit(t);
    expect(session.session, isNull);
    expect(find.text('Cambios guardados correctamente.'), findsNothing);
  });
}
