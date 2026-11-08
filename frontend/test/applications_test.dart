import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/app.dart';
import 'package:worknet/features/applications/domain/application.dart';
import 'package:worknet/features/applications/data/applications_repository.dart';
import 'package:worknet/features/applications/presentation/apply_page.dart';
import 'package:worknet/features/applications/presentation/application_history_page.dart';
import 'offer_search_test.dart' show candidateSession;
import 'support/access_fakes.dart'
    show jsonResponse, sessionData, MemorySessionStore;

const uploaded = CvChoice(
  source: 'uploaded',
  id: 1,
  revision: '2026-11-08T12:00:00Z',
  label: 'cv-subido.pdf',
);
const generated = CvChoice(
  source: 'generated',
  id: 2,
  revision: '2026-11-08T12:00:00Z',
  label: 'CV Moderna',
);
const activeOffer = ApplicationOffer(
  id: 3,
  title: 'Oferta QA',
  company: 'Empresa QA',
  location: 'Pasto',
  contract: 'Indefinido',
  status: 'published',
  active: true,
);
const inactiveOffer = ApplicationOffer(
  id: 3,
  title: 'Oferta QA',
  company: 'Empresa QA',
  location: 'Pasto',
  contract: 'Indefinido',
  status: 'closed',
  active: false,
);
JobApplication receipt({
  CvChoice cv = uploaded,
  int id = 1,
  ApplicationOffer offer = activeOffer,
}) => JobApplication(
  id: id,
  offer: offer,
  createdAt: DateTime.utc(2026, 11, 8, 12),
  cv: SentCv(
    source: cv.source,
    filename: cv.label,
    sha256: 'a' * 64,
    sourceId: cv.id,
    size: 1000,
  ),
);
Map<String, dynamic> offerJson() => {
  'id': 3,
  'title': 'Oferta QA',
  'company_name': 'Empresa QA',
  'location': 'Pasto',
  'contract_type': 'Indefinido',
  'status': 'published',
  'is_active': true,
};
Map<String, dynamic> applicationJson() => {
  'id': 1,
  'offer': offerJson(),
  'created_at': '2026-11-08T12:01:00Z',
  'status': 'submitted',
  'cv': {
    'source': 'uploaded',
    'source_id': 1,
    'source_updated_at': uploaded.revision,
    'filename': 'cv-subido.pdf',
    'template': '',
    'sha256': 'a' * 64,
    'size_bytes': 1000,
  },
};
Map<String, dynamic> contextJson() => {
  'offer': offerJson(),
  'candidate': {'full_name': 'Candidato QA'},
  'cv_options': [
    {
      'source': uploaded.source,
      'id': uploaded.id,
      'revision': uploaded.revision,
      'label': uploaded.label,
    },
    {
      'source': generated.source,
      'id': generated.id,
      'revision': generated.revision,
      'label': generated.label,
    },
  ],
  'application': null,
};

class ApplicationsFake implements ApplicationsRepository {
  List<CvChoice> choices = [uploaded, generated];
  ApplicationOffer offer = activeOffer;
  JobApplication? existing;
  ApiFailure? contextFailure, submitFailure, historyFailure, pdfFailure;
  bool acceptBeforeFailure = false;
  Completer<ApplicationContext>? pending;
  final submitted = <CvChoice>[];
  final pages = <int>[];
  final entries = <JobApplication>[];
  @override
  Future<ApplicationContext> context(String token, int offerId) async {
    if (contextFailure case final e?) throw e;
    return pending?.future ??
        ApplicationContext(
          offer: offer,
          candidateName: 'Candidato QA',
          choices: choices,
          existing: existing,
        );
  }

  @override
  Future<JobApplication> submit(String token, int offerId, CvChoice cv) async {
    submitted.add(cv);
    if (acceptBeforeFailure) existing = receipt(cv: cv);
    if (submitFailure case final e?) throw e;
    return existing ??= receipt(cv: cv);
  }

  @override
  Future<ApplicationHistory> history(String token, {int page = 1}) async {
    pages.add(page);
    if (historyFailure case final e?) throw e;
    final total = (entries.length / 10).ceil();
    return ApplicationHistory(
      applications: entries.skip((page - 1) * 10).take(10).toList(),
      count: entries.length,
      page: page,
      pages: total,
      next: page < total ? page + 1 : null,
      previous: page > 1 ? page - 1 : null,
    );
  }

  @override
  Future<Uint8List> pdf(String token, int applicationId) async {
    throw pdfFailure ?? const ApiFailure('PDF no disponible');
  }
}

Future<void> tapText(WidgetTester t, String label) async {
  final f = find.text(label).last;
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> pageSize(WidgetTester t) async {
  t.view.physicalSize = const Size(1000, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'without CV creates one and returns to the same offer with refreshed options',
    (t) async {
      await pageSize(t);
      var saved = false, loads = 0;
      final data = <String, dynamic>{
        'personal': {
          'full_name': 'Candidata QA',
          'email': 'qa@example.test',
          'phone': '',
          'location': '',
          'website': '',
        },
        'professional_summary': '',
        'education': [],
        'experience': [],
        'skills': [],
        'languages': [],
        'certifications': [],
        'extra_sections': [],
      };
      final api = WorkNetApi(
        client: MockClient((r) async {
          final path = r.url.path;
          if (path == '/api/offers/3/application/') {
            loads++;
            final body = contextJson();
            body['cv_options'] = saved
                ? [
                    {
                      'source': generated.source,
                      'id': generated.id,
                      'revision': generated.revision,
                      'label': generated.label,
                    },
                  ]
                : [];
            return jsonResponse(body);
          }
          if (path == '/api/curriculum/') {
            return jsonResponse({
              'uploaded': null,
              'generated': null,
              'options': [],
              'limits': {'max_upload_bytes': 5242880, 'max_upload_pages': 50},
            });
          }
          if (path == '/api/curriculum/generated/') {
            if (r.method == 'PUT') {
              saved = true;
            }
            return jsonResponse({
              'exists': saved,
              'curriculum': {'template': 'moderna', 'data': data},
            }, r.method == 'PUT' ? 201 : 200);
          }
          throw StateError('Unexpected test route: $path');
        }),
      );
      final store = MemorySessionStore()..value = jsonEncode(sessionData());
      await t.pumpWidget(
        WorkNetApp(
          api: api,
          sessionStore: store,
          initialLocation: '/offers/3/apply',
        ),
      );
      await t.pumpAndSettle();
      await tapText(t, 'Ir a Mi currículum');
      await tapText(t, 'Crear mi CV');
      expect(
        t
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Continuar postulación'),
            )
            .onPressed,
        isNull,
      );
      await tapText(t, 'Guardar CV');
      await tapText(t, 'Continuar postulación');
      expect(find.text('Postular a oferta'), findsOneWidget);
      expect(find.text('CV generado: CV Moderna'), findsOneWidget);
      expect(loads, 2);
      expect(saved, true);
    },
  );
  test(
    'HTTP context and selected source/revision use private session and confirmed receipt',
    () async {
      final calls = <String>[];
      final api = WorkNetApi(
        client: MockClient((r) async {
          expect(r.headers['Authorization'], 'Token private-test');
          calls.add(r.method);
          if (r.method == 'GET') return jsonResponse(contextJson());
          expect(r.url.path, '/api/offers/3/application/');
          expect(r.body, contains('"cv_source":"uploaded"'));
          expect(r.body, contains('"cv_revision":"${uploaded.revision}"'));
          expect(r.body, contains('"confirm":true'));
          expect(r.body, isNot(contains('candidate_id')));
          return jsonResponse({
            'created': true,
            'application': applicationJson(),
          }, 201);
        }),
      );
      final repo = HttpApplicationsRepository(api),
          data = await repo.context('private-test', 3);
      expect(data.choices.map((c) => c.source), ['uploaded', 'generated']);
      final sent = await repo.submit('private-test', 3, data.choices.first);
      expect(sent.cv!.filename, 'cv-subido.pdf');
      expect(sent.createdAt.isUtc, true);
      expect(calls, ['GET', 'POST']);
    },
  );

  test(
    'malformed or contradictory success never confirms an application',
    () async {
      for (final row in [
        applicationJson()..['id'] = 0,
        applicationJson()..['status'] = 'unknown',
        applicationJson()..['offer'] = (offerJson()..['id'] = 8),
        applicationJson()..['cv'] = {'source': 'uploaded'},
      ]) {
        final repo = HttpApplicationsRepository(
          WorkNetApi(
            client: MockClient(
              (_) async => jsonResponse({'created': true, 'application': row}),
            ),
          ),
        );
        await expectLater(
          repo.submit('private-test', 3, uploaded),
          throwsA(isA<ApiFailure>()),
        );
      }
      final raw = contextJson();
      raw['cv_options'] = [raw['cv_options'][0], raw['cv_options'][0]];
      final repo = HttpApplicationsRepository(
        WorkNetApi(client: MockClient((_) async => jsonResponse(raw))),
      );
      await expectLater(
        repo.context('private-test', 3),
        throwsA(isA<ApiFailure>()),
      );
    },
  );

  test(
    'history supports honest legacy entry and rejects inconsistent pagination',
    () async {
      final row = applicationJson()..['cv'] = null;
      var malformed = false;
      final repo = HttpApplicationsRepository(
        WorkNetApi(
          client: MockClient(
            (_) async => jsonResponse({
              'count': 1,
              'page': 1,
              'page_size': 10,
              'total_pages': malformed ? 2 : 1,
              'next_page': null,
              'previous_page': null,
              'applications': [row],
            }),
          ),
        ),
      );
      expect(
        (await repo.history('private-test')).applications.single.cv,
        isNull,
      );
      malformed = true;
      await expectLater(
        repo.history('private-test'),
        throwsA(isA<ApiFailure>()),
      );
    },
  );

  testWidgets(
    'choose generated CV review and confirm only after server acceptance',
    (t) async {
      await pageSize(t);
      final session = await candidateSession(), repo = ApplicationsFake();
      await t.pumpWidget(
        MaterialApp(
          home: ApplyPage(session: session, repository: repo, offerId: 3),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButton<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('CV generado: CV Moderna').last);
      await t.pumpAndSettle();
      await tapText(t, 'Continuar');
      expect(find.text('CV generado: CV Moderna'), findsOneWidget);
      expect(repo.submitted, isEmpty);
      await tapText(t, 'Confirmar postulación');
      expect(repo.submitted.single.source, 'generated');
      expect(
        find.text('Postulación registrada correctamente.'),
        findsOneWidget,
      );
      expect(find.text('Estado de postulación: Enviada'), findsOneWidget);
      expect(find.text('Confirmar postulación'), findsNothing);
    },
  );

  testWidgets('loading and absent CV do not send applications', (t) async {
    await pageSize(t);
    final session = await candidateSession(),
        repo = ApplicationsFake()..pending = Completer<ApplicationContext>();
    await t.pumpWidget(
      MaterialApp(
        home: ApplyPage(session: session, repository: repo, offerId: 3),
      ),
    );
    await t.pump();
    expect(find.text('Cargando postulación…'), findsOneWidget);
    repo.pending!.complete(
      const ApplicationContext(
        offer: activeOffer,
        candidateName: 'Candidato QA',
        choices: [],
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Ir a Mi currículum'), findsOneWidget);
    expect(find.text('Continuar'), findsNothing);
    expect(repo.submitted, isEmpty);
  });

  testWidgets(
    'lost response reconciles actual registered application without another POST',
    (t) async {
      await pageSize(t);
      final session = await candidateSession(),
          repo = ApplicationsFake()
            ..submitFailure = const ApiFailure('Respuesta perdida QA')
            ..acceptBeforeFailure = true;
      await t.pumpWidget(
        MaterialApp(
          home: ApplyPage(session: session, repository: repo, offerId: 3),
        ),
      );
      await t.pumpAndSettle();
      await tapText(t, 'Continuar');
      await tapText(t, 'Confirmar postulación');
      expect(find.text('Postulación registrada correctamente.'), findsNothing);
      await tapText(t, 'Comprobar postulación');
      expect(
        find.text('Postulación registrada correctamente.'),
        findsOneWidget,
      );
      expect(repo.submitted.length, 1);
    },
  );

  testWidgets(
    'rejected send remains unconfirmed and recovery loads current CV choices',
    (t) async {
      await pageSize(t);
      final session = await candidateSession(),
          repo = ApplicationsFake()
            ..submitFailure = const ApiFailure('No se aceptó', status: 503);
      await t.pumpWidget(
        MaterialApp(
          home: ApplyPage(session: session, repository: repo, offerId: 3),
        ),
      );
      await t.pumpAndSettle();
      await tapText(t, 'Continuar');
      await tapText(t, 'Confirmar postulación');
      expect(find.text('Postulación registrada correctamente.'), findsNothing);
      repo.choices = [generated];
      repo.submitFailure = null;
      await tapText(t, 'Comprobar postulación');
      expect(find.text('CV generado: CV Moderna'), findsOneWidget);
      await tapText(t, 'Continuar');
      await tapText(t, 'Confirmar postulación');
      expect(repo.submitted.last.source, 'generated');
    },
  );

  testWidgets(
    'inactive offer is readable but cannot proceed and history preserves state',
    (t) async {
      await pageSize(t);
      final session = await candidateSession(),
          repo = ApplicationsFake()..offer = inactiveOffer;
      await t.pumpWidget(
        MaterialApp(
          home: ApplyPage(session: session, repository: repo, offerId: 3),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text(
          'Esta oferta ya no está activa y no recibe nuevas postulaciones.',
        ),
        findsOneWidget,
      );
      expect(find.text('Continuar'), findsNothing);
      repo.entries.add(receipt(offer: inactiveOffer));
      await t.pumpWidget(
        MaterialApp(
          home: ApplicationHistoryPage(session: session, repository: repo),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.text(
          'La oferta ya no está activa. Tu postulación y el CV enviado se conservan.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('history empty errors retry and pagination work on mobile', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final session = await candidateSession(),
        repo = ApplicationsFake()..historyFailure = const ApiFailure('Red QA');
    await t.pumpWidget(
      MaterialApp(
        home: ApplicationHistoryPage(session: session, repository: repo),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Red QA'), findsOneWidget);
    repo.historyFailure = null;
    await tapText(t, 'Reintentar');
    expect(find.text('0 postulaciones registradas'), findsOneWidget);
    repo.entries.addAll(List.generate(11, (i) => receipt(id: i + 1)));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpWidget(
      MaterialApp(
        home: ApplicationHistoryPage(session: session, repository: repo),
      ),
    );
    await t.pumpAndSettle();
    await tapText(t, 'Siguiente');
    expect(find.text('Página 2 de 2'), findsOneWidget);
    expect(repo.pages.last, 2);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'PDF failure has retry and session expiry clears authenticated state',
    (t) async {
      await pageSize(t);
      final session = await candidateSession(),
          repo = ApplicationsFake()..entries.add(receipt());
      await t.pumpWidget(
        MaterialApp(
          home: ApplicationHistoryPage(session: session, repository: repo),
        ),
      );
      await t.pumpAndSettle();
      await tapText(t, 'Ver CV enviado');
      expect(find.text('PDF no disponible'), findsOneWidget);
      expect(find.text('Reintentar PDF'), findsOneWidget);
      repo.pdfFailure = const ApiFailure('Sesión vencida', status: 401);
      await tapText(t, 'Reintentar PDF');
      expect(session.session, isNull);
    },
  );
}
