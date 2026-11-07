import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/access/data/access_repository.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/offers/data/offer_repository.dart';
import 'package:worknet/features/offers/domain/offer.dart';
import 'package:worknet/features/offers/presentation/publish_offer_page.dart';
import 'support/access_fakes.dart';

class FakeOffers implements OfferRepository {
  int calls = 0;
  OfferDraft? draft;
  ApiFailure? failure;
  Completer<int>? pending;
  @override
  Future<OfferCatalog> catalog(String token) async => const OfferCatalog(
    categories: ['Tecnología'],
    contractTypes: ['Indefinido'],
  );
  @override
  Future<int> publish(String token, OfferDraft value) async {
    calls++;
    draft = value;
    if (failure != null) throw failure!;
    return pending?.future ?? 42;
  }
}

Future<SessionController> companySession() async {
  final api = WorkNetApi(
    client: MockClient((r) async => jsonResponse(sessionData(role: 'empresa'))),
  );
  final session = SessionController(
    repository: HttpAccessRepository(api, MemorySessionStore()),
  );
  await session.login('qa@example.com', 'local', remember: false);
  return session;
}

Future<void> fill(WidgetTester t) async {
  for (final e in {
    'title': 'Oferta QA',
    'description': 'Descripción',
    'requirements': 'Requisitos',
    'salary': '2500000,50',
    'location': 'Pasto',
  }.entries) {
    await t.ensureVisible(find.byKey(Key('offer_${e.key}')));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(Key('offer_${e.key}')), e.value);
  }
  for (final e in {
    'category': 'Tecnología',
    'contract': 'Indefinido',
  }.entries) {
    await t.ensureVisible(find.byKey(Key('offer_${e.key}')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(Key('offer_${e.key}')));
    await t.pumpAndSettle();
    await t.tap(find.text(e.value).last);
    await t.pumpAndSettle();
  }
}

Future<void> submit(WidgetTester t) async {
  await t.ensureVisible(find.byKey(const Key('offer_publish')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('offer_publish')));
  await t.pumpAndSettle();
}

void main() {
  test(
    'HTTP adapter sends authenticated fields and reads catalog/result',
    () async {
      var calls = 0;
      final api = WorkNetApi(
        client: MockClient((r) async {
          calls++;
          expect(r.url.path, '/api/company/offers/');
          expect(r.headers['Authorization'], 'Token local');
          if (r.method == 'GET') {
            return jsonResponse({
              'categories': ['Tecnología'],
              'contract_types': ['Indefinido'],
            });
          }
          final body = jsonDecode(r.body) as Map;
          expect(body['salary'], '123.50');
          expect(body.containsKey('company'), false);
          return jsonResponse({
            'offer': {'id': 7},
          }, 201);
        }),
      );
      final repository = HttpOfferRepository(api);
      expect((await repository.catalog('local')).categories, ['Tecnología']);
      expect(
        await repository.publish(
          'local',
          const OfferDraft(
            title: 'QA',
            description: 'QA',
            requirements: 'QA',
            salary: '123.50',
            location: 'Pasto',
            category: 'Tecnología',
            contractType: 'Indefinido',
          ),
        ),
        7,
      );
      expect(calls, 2);
    },
  );
  testWidgets('required validation prevents requests', (t) async {
    final repo = FakeOffers();
    final session = await companySession();
    await t.pumpWidget(
      MaterialApp(
        home: PublishOfferPage(session: session, repository: repo),
      ),
    );
    await t.pumpAndSettle();
    await submit(t);
    expect(repo.calls, 0);
    expect(find.text('Completa este campo.'), findsWidgets);
  });
  testWidgets('publishes once and shows confirmation', (t) async {
    final repo = FakeOffers();
    final session = await companySession();
    await t.pumpWidget(
      MaterialApp(
        home: PublishOfferPage(session: session, repository: repo),
      ),
    );
    await t.pumpAndSettle();
    await fill(t);
    await submit(t);
    expect(repo.calls, 1);
    expect(repo.draft!.salary, '2500000.50');
    expect(find.byKey(const Key('offer_success')), findsOneWidget);
    expect(find.byKey(const Key('offer_publish')), findsNothing);
  });
  testWidgets('network error preserves draft and permits retry', (t) async {
    final repo = FakeOffers()..failure = const ApiFailure('Sin conexión');
    final session = await companySession();
    await t.pumpWidget(
      MaterialApp(
        home: PublishOfferPage(session: session, repository: repo),
      ),
    );
    await t.pumpAndSettle();
    await fill(t);
    await submit(t);
    expect(repo.calls, 1);
    expect(
      t
          .widget<TextFormField>(find.byKey(const Key('offer_title')))
          .controller!
          .text,
      'Oferta QA',
    );
    repo.failure = null;
    await submit(t);
    expect(repo.calls, 2);
    expect(find.byKey(const Key('offer_success')), findsOneWidget);
  });
  testWidgets('pending request disables duplicate submission', (t) async {
    final repo = FakeOffers()..pending = Completer<int>();
    final session = await companySession();
    await t.pumpWidget(
      MaterialApp(
        home: PublishOfferPage(session: session, repository: repo),
      ),
    );
    await t.pumpAndSettle();
    await fill(t);
    await submit(t);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('offer_publish'))).onPressed,
      isNull,
    );
    expect(repo.calls, 1);
    repo.pending!.complete(12);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('offer_success')), findsOneWidget);
  });
}
