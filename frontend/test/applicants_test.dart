import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/applicants/data/applicants_repository.dart';
import 'package:worknet/features/applicants/domain/applicant.dart';
import 'package:worknet/features/applicants/presentation/applicants_page.dart';
import 'package:worknet/features/applicants/presentation/applicant_detail_page.dart';
import 'package:worknet/features/applicants/presentation/applicant_offers_page.dart';
import 'package:worknet/features/profile/domain/profile.dart';
import 'applications_test.dart'
    show applicationJson, offerJson, receipt, activeOffer;
import 'publish_offer_test.dart' show companySession;
import 'support/access_fakes.dart' show jsonResponse;

Map<String, dynamic> paging(List<dynamic> rows, String key) => {
  'count': rows.length,
  'page': 1,
  'page_size': 10,
  'total_pages': rows.isEmpty ? 0 : 1,
  'next_page': null,
  'previous_page': null,
  key: rows,
};
Map<String, dynamic> applicantJson() => {
  ...applicationJson(),
  'candidate': {'id': 2, 'full_name': 'Persona ficticia QA'},
};
Map<String, dynamic> profileJson() => {
  'application': {'id': 1, 'offer_id': 3},
  'candidate': {'id': 2, 'full_name': 'Persona ficticia QA'},
  'profile': {
    'exists': true,
    'professional_summary': 'Perfil actual QA',
    'has_photo': false,
    'experience': [
      {'id': 'e', 'position': 'Ingeniera Backend'},
    ],
    'education': [
      {'id': 'd', 'qualification': 'Ingeniería'},
    ],
    'skills': [
      {'id': 's', 'name': 'Python'},
    ],
    'languages': [],
  },
  'profile_completion': {'percentage': 67},
};

class ApplicantsFake implements ApplicantsRepository {
  final calls = <ApplicantQuery>[];
  ApiFailure? failure;
  int count = 11;
  @override
  Future<ApplicantOffers> offers(String token, {int page = 1}) async {
    if (failure != null) throw failure!;
    return const ApplicantOffers(
      offers: [
        ApplicantOffer(id: 3, title: 'Oferta QA', status: 'closed', count: 11),
      ],
      count: 1,
      page: 1,
      pages: 1,
    );
  }

  @override
  Future<ApplicantPage> applicants(
    String token,
    int offerId,
    ApplicantQuery query,
  ) async {
    calls.add(query);
    if (failure != null) throw failure!;
    final pages = (count / 10).ceil(), start = (query.page - 1) * 10;
    return ApplicantPage(
      offer: activeOffer,
      applicants: List.generate(
        (count - start).clamp(0, 10).toInt(),
        (i) => Applicant(
          application: receipt(id: start + i + 1),
          candidateId: start + i + 2,
          name: 'Persona QA ${start + i + 1}',
        ),
      ),
      count: count,
      page: query.page,
      pages: pages,
      next: query.page < pages ? query.page + 1 : null,
      previous: query.page > 1 ? query.page - 1 : null,
    );
  }

  @override
  Future<ApplicantDetail> detail(
    String token,
    int offerId,
    int applicationId,
  ) async {
    if (failure != null) throw failure!;
    return ApplicantDetail(
      applicant: Applicant(
        application: receipt(id: applicationId),
        candidateId: 2,
        name: 'Persona ficticia QA',
      ),
      profile: const CandidateProfile(
        exists: true,
        summary: 'Perfil actual QA',
        hasPhoto: false,
        percentage: 50,
        entries: {
          'experience': [
            {'id': 'e', 'position': 'Backend'},
          ],
          'education': [],
          'skills': [
            {'id': 's', 'name': 'Python'},
          ],
          'languages': [],
        },
      ),
    );
  }

  @override
  Future<Uint8List> pdf(String token, int applicationId) async =>
      throw const ApiFailure('Documento ausente QA', status: 404);
}

Future<void> tap(WidgetTester t, Finder f) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await t.pumpAndSettle();
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  test(
    'HTTP selection and literal combined filters use private session and bound page',
    () async {
      final api = WorkNetApi(
        client: MockClient((r) async {
          expect(r.headers['Authorization'], 'Token fake-private-qa');
          expect(r.method, 'GET');
          if (r.url.path.endsWith('applicant-offers/')) {
            return jsonResponse(
              paging([
                {
                  'id': 3,
                  'title': 'Oferta QA',
                  'status': 'closed',
                  'applicants_count': 1,
                },
              ], 'offers'),
            );
          }
          expect(r.url.queryParameters['skill'], 'Python & Django');
          expect(r.url.queryParameters['experience'], 'Backend');
          expect(r.url.queryParameters['education'], 'Ingeniería');
          expect(r.url.queryParameters['page_size'], '10');
          expect(r.url.queryParameters['order'], 'name');
          return jsonResponse({
            ...paging([applicantJson()], 'applications'),
            'offer': offerJson(),
            'filter_scope': 'current_profile',
          });
        }),
      );
      final repo = HttpApplicantsRepository(api);
      expect(
        (await repo.offers('fake-private-qa')).offers.single.status,
        'closed',
      );
      final data = await repo.applicants(
        'fake-private-qa',
        3,
        const ApplicantQuery(
          experience: 'Backend',
          education: 'Ingeniería',
          skill: 'Python & Django',
          order: 'name',
        ),
      );
      expect(data.applicants.single.name, 'Persona ficticia QA');
    },
  );
  test(
    'list rejects mixed offers duplicated records wrong pagination and malformed rows',
    () async {
      dynamic rows = [
        {
          ...applicantJson(),
          'offer': {...offerJson(), 'id': 4},
        },
      ];
      var scope = 'current_profile';
      final repo = HttpApplicantsRepository(
        WorkNetApi(
          client: MockClient(
            (_) async => jsonResponse({
              ...paging(rows, 'applications'),
              'offer': offerJson(),
              'filter_scope': scope,
            }),
          ),
        ),
      );
      await expectLater(
        repo.applicants('qa', 3, const ApplicantQuery()),
        throwsA(isA<ApiFailure>()),
      );
      rows = [applicantJson(), applicantJson()];
      await expectLater(
        repo.applicants('qa', 3, const ApplicantQuery()),
        throwsA(isA<ApiFailure>()),
      );
      rows = [null];
      await expectLater(
        repo.applicants('qa', 3, const ApplicantQuery()),
        throwsA(isA<ApiFailure>()),
      );
      rows = [];
      scope = 'pdf';
      await expectLater(
        repo.applicants('qa', 3, const ApplicantQuery()),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
  test(
    'detail joins only the same application offer and candidate with the authorized profile',
    () async {
      var candidate = 2;
      final repo = HttpApplicantsRepository(
        WorkNetApi(
          client: MockClient(
            (r) async => r.url.path.endsWith('/profile/')
                ? jsonResponse({
                    ...profileJson(),
                    'candidate': {'id': candidate, 'full_name': 'Persona QA'},
                  })
                : jsonResponse({
                    'application': applicationJson(),
                    'candidate': {'id': 2, 'full_name': 'Persona QA'},
                  }),
          ),
        ),
      );
      final d = await repo.detail('qa', 3, 1);
      expect(d.profile.summary, 'Perfil actual QA');
      expect(d.applicant.application.cv!.source, 'uploaded');
      candidate = 9;
      await expectLater(repo.detail('qa', 3, 1), throwsA(isA<ApiFailure>()));
      candidate = 2;
      await expectLater(repo.detail('qa', 4, 1), throwsA(isA<ApiFailure>()));
    },
  );
  testWidgets(
    'combined filters preserve order on next page and reset when changed or cleared',
    (t) async {
      t.view.physicalSize = const Size(1440, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final session = await companySession(), repo = ApplicantsFake();
      final router = GoRouter(
        initialLocation: '/company/offers/3/applicants',
        routes: [
          GoRoute(
            path: '/company/offers/:id/applicants',
            builder: (_, s) => ApplicantsPage(
              key: ValueKey(s.uri.toString()),
              session: session,
              repository: repo,
              offerId: 3,
              query: ApplicantQuery.fromUri(s.uri),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextFormField, 'Experiencia'),
        'Backend',
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Educación'),
        'Ingeniería',
      );
      await t.enterText(
        find.widgetWithText(TextFormField, 'Habilidad'),
        'Python',
      );
      await tap(t, find.byType(DropdownButtonFormField<String>));
      await tap(t, find.text('Nombre A–Z').last);
      await tap(t, find.text('Aplicar filtros'));
      expect(repo.calls.last.page, 1);
      await tap(t, find.text('Siguiente'));
      expect(repo.calls.last.page, 2);
      expect(repo.calls.last.order, 'name');
      expect(repo.calls.last.skill, 'Python');
      expect(repo.calls.last.education, 'Ingeniería');
      expect(repo.calls.last.experience, 'Backend');
      await t.ensureVisible(find.widgetWithText(TextFormField, 'Habilidad'));
      await t.enterText(
        find.widgetWithText(TextFormField, 'Habilidad'),
        'Rust',
      );
      await tap(t, find.text('Aplicar filtros'));
      expect(repo.calls.last.page, 1);
      expect(repo.calls.last.skill, 'Rust');
      await tap(t, find.text('Limpiar filtros'));
      expect(repo.calls.last.page, 1);
      expect(repo.calls.last.skill, '');
      expect(repo.calls.last.order, 'newest');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('mobile list handles error retry empty state without overflow', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final session = await companySession(),
        repo = ApplicantsFake()..failure = const ApiFailure('Red QA');
    await t.pumpWidget(
      MaterialApp(
        home: ApplicantsPage(
          session: session,
          repository: repo,
          offerId: 3,
          query: const ApplicantQuery(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Red QA'), findsOneWidget);
    repo.failure = null;
    repo.count = 0;
    await tap(t, find.text('Reintentar'));
    expect(
      find.text('No hay postulantes que coincidan con esta consulta.'),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'company detail reads current structured profile and offers the actual sent CV',
    (t) async {
      final session = await companySession(), repo = ApplicantsFake();
      await t.pumpWidget(
        MaterialApp(
          home: ApplicantDetailPage(
            session: session,
            repository: repo,
            offerId: 3,
            id: 1,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Persona ficticia QA'), findsOneWidget);
      expect(find.text('Perfil actual QA'), findsOneWidget);
      expect(find.text('Python'), findsOneWidget);
      expect(find.text('Ver CV enviado'), findsOneWidget);
      repo.failure = const ApiFailure('Sin permiso', status: 403);
      await tap(t, find.text('Actualizar detalle'));
      expect(find.text('Perfil actual QA'), findsNothing);
      expect(find.text('Sin permiso'), findsOneWidget);
    },
  );
  testWidgets('selection shows own preserved offer and empty states honestly', (
    t,
  ) async {
    final session = await companySession(), repo = ApplicantsFake();
    await t.pumpWidget(
      MaterialApp(
        home: ApplicantOffersPage(session: session, repository: repo),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Estado de la oferta: Cerrada'), findsOneWidget);
    expect(find.text('Ver postulantes'), findsOneWidget);
  });
}
