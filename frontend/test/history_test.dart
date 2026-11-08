import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/applications/data/applications_repository.dart';
import 'package:worknet/features/applications/domain/application.dart';
import 'package:worknet/features/applications/presentation/application_detail_page.dart';
import 'package:worknet/features/applications/presentation/application_history_page.dart';
import 'applications_test.dart'
    show ApplicationsFake, applicationJson, activeOffer, receipt;
import 'offer_search_test.dart' show candidateSession;
import 'support/access_fakes.dart' show jsonResponse;

JobApplication stateReceipt(ApplicationStatus state) => JobApplication(
  id: 1,
  offer: activeOffer,
  createdAt: DateTime.utc(2026, 11, 8),
  cv: receipt().cv,
  status: state,
);

void main() {
  test(
    'history contract accepts exactly the four persisted states and checks detail ID',
    () async {
      var state = 'submitted', id = 1;
      final api = WorkNetApi(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, endsWith('/applications/1/'));
          return jsonResponse({
            'application': {...applicationJson(), 'id': id, 'status': state},
          });
        }),
      );
      final repo = HttpApplicationsRepository(api);
      for (final value in ApplicationStatus.values) {
        state = value.code;
        expect((await repo.detail('qa-private-test', 1)).status, value);
      }
      state = 'inventado';
      await expectLater(
        repo.detail('qa-private-test', 1),
        throwsA(isA<ApiFailure>()),
      );
      state = 'submitted';
      id = 2;
      await expectLater(
        repo.detail('qa-private-test', 1),
        throwsA(isA<ApiFailure>()),
      );
    },
  );

  testWidgets(
    'history refreshes after returning from detail and explicit update',
    (t) async {
      t.view.physicalSize = const Size(1440, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final session = await candidateSession(),
          repo = ApplicationsFake()
            ..entries.add(stateReceipt(ApplicationStatus.submitted));
      final router = GoRouter(
        initialLocation: '/applications',
        routes: [
          GoRoute(
            path: '/applications',
            builder: (_, _) =>
                ApplicationHistoryPage(session: session, repository: repo),
          ),
          GoRoute(
            path: '/applications/:id',
            builder: (_, _) => ApplicationDetailPage(
              session: session,
              repository: repo,
              id: 1,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      expect(find.text('Estado de postulación: Enviada'), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('application_detail_1')));
      await t.tap(find.byKey(const Key('application_detail_1')));
      await t.pumpAndSettle();
      expect(find.text('Detalle de postulación'), findsOneWidget);
      repo.entries[0] = stateReceipt(ApplicationStatus.inReview);
      await t.tap(find.text('Actualizar detalle'));
      await t.pumpAndSettle();
      expect(find.text('Estado de postulación: En revisión'), findsOneWidget);
      await t.tap(find.text('Volver al historial'));
      await t.pumpAndSettle();
      expect(find.text('Estado de postulación: En revisión'), findsOneWidget);
      repo.entries[0] = stateReceipt(ApplicationStatus.accepted);
      await t.tap(find.text('Actualizar historial'));
      await t.pumpAndSettle();
      expect(find.text('Estado de postulación: Aceptada'), findsOneWidget);
      repo.entries[0] = stateReceipt(ApplicationStatus.rejected);
      await t.tap(find.text('Actualizar historial'));
      await t.pumpAndSettle();
      expect(find.text('Estado de postulación: Rechazada'), findsOneWidget);
    },
  );

  testWidgets(
    'detail shows legacy document absence and real API errors without stale data',
    (t) async {
      final session = await candidateSession();
      var fail = true;
      final api = WorkNetApi(
        client: MockClient(
          (_) async => fail
              ? jsonResponse({
                  'detail': 'No encontramos esa postulación en tu cuenta.',
                }, 404)
              : jsonResponse({
                  'application': {
                    ...applicationJson(),
                    'cv': null,
                    'status': 'rejected',
                  },
                }),
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          home: ApplicationDetailPage(
            session: session,
            repository: HttpApplicationsRepository(api),
            id: 1,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Estado de postulación: Rechazada'), findsNothing);
      fail = false;
      await t.tap(find.text('Reintentar'));
      await t.pumpAndSettle();
      expect(
        find.text('Esta postulación anterior no tiene un CV registrado.'),
        findsOneWidget,
      );
      expect(find.text('Estado de postulación: Rechazada'), findsOneWidget);
      expect(find.text('Ver CV enviado'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
}
