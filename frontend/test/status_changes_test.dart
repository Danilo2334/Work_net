import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/core/api/operation_id.dart';
import 'package:worknet/features/applications/domain/application.dart';
import 'package:worknet/features/applications/data/applications_repository.dart';
import 'package:worknet/features/status_changes/domain/status_change.dart';
import 'package:worknet/features/status_changes/data/status_repository.dart';
import 'package:worknet/features/status_changes/presentation/status_change_panel.dart';
import 'applications_test.dart' show applicationJson, receipt;
import 'publish_offer_test.dart' show companySession;
import 'support/access_fakes.dart' show jsonResponse;
import 'support/status_fakes.dart';

void main() {
  test('status metadata is preserved and old unknown dates stay null', () {
    final repo = HttpApplicationsRepository(WorkNetApi());
    expect(repo.decodeApplication(applicationJson()).statusModifiedAt, isNull);
    final item = repo.decodeApplication({
      ...applicationJson(),
      'status': 'in_review',
      'status_change': {
        'version': 1,
        'modified_at': '2026-11-08T20:00:00Z',
        'comment': 'Revisado',
      },
    });
    expect(item.statusVersion, 1);
    expect(item.statusComment, 'Revisado');
    expect(item.statusModifiedAt, DateTime.utc(2026, 11, 8, 20));
    expect(
      () => repo.decodeApplication({
        ...applicationJson(),
        'status_change': {'version': -1, 'modified_at': null, 'comment': ''},
      }),
      throwsA(isA<ApiFailure>()),
    );
  });
  test(
    'status adapter sends confirmed version and same operation ID, validates receipt',
    () async {
      final command = StatusCommand(
        id: newOperationId(),
        version: 0,
        target: ApplicationStatus.accepted,
        comment: 'Aprobado',
      );
      var corrupt = false;
      final api = WorkNetApi(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            final b = jsonDecode(request.body) as Map;
            expect(b, {
              'target_status': 'accepted',
              'expected_version': 0,
              'request_id': command.id,
              'comment': 'Aprobado',
              'confirm': true,
            });
          }
          return jsonResponse({
            'application': {
              ...applicationJson(),
              'status': 'accepted',
              'status_change': {
                'version': 1,
                'modified_at': '2026-11-08T20:00:00Z',
                'comment': 'Aprobado',
              },
            },
            'allowed_transitions': [],
            'event': {
              'request_id': corrupt ? newOperationId() : command.id,
              'version': 1,
              'to_status': 'accepted',
              'comment': 'Aprobado',
              'changed_at': '2026-11-08T20:00:00Z',
            },
          });
        }),
      );
      final repo = HttpStatusRepository(api);
      expect(
        (await repo.change('qa-private', 1, command)).recordedTarget,
        ApplicationStatus.accepted,
      );
      expect(
        (await repo.lookup('qa-private', 1, command)).application.statusVersion,
        1,
      );
      corrupt = true;
      await expectLater(
        repo.change('qa-private', 1, command),
        throwsA(isA<ApiFailure>()),
      );
    },
  );

  Future<StatusFake> mount(WidgetTester t, {bool lost = false}) async {
    t.view.physicalSize = const Size(1100, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final session = await companySession(),
        repo = StatusFake(receipt())..loseResponse = lost;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatusChangePanel(
              session: session,
              repository: repo,
              id: 1,
              onChanged: () async {},
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    return repo;
  }

  Future<void> choose(WidgetTester t, String label) async {
    await t.tap(find.byType(DropdownButtonFormField<ApplicationStatus>));
    await t.pumpAndSettle();
    await t.tap(find.text(label).last);
    await t.pumpAndSettle();
  }

  testWidgets('confirmation cancel conserves state, comment and no request', (
    t,
  ) async {
    final repo = await mount(t);
    await choose(t, 'En revisión');
    await t.enterText(find.byType(TextField), 'Revisión QA');
    await t.tap(find.text('Revisar cambio'));
    await t.pumpAndSettle();
    expect(find.text('Confirmar cambio de estado'), findsOneWidget);
    expect(repo.writes, 0);
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(repo.writes, 0);
    expect(repo.application.statusVersion, 0);
    expect(find.text('Revisión QA'), findsOneWidget);
  });
  testWidgets(
    'confirmed decision changes only after server receipt and is terminal',
    (t) async {
      final repo = await mount(t);
      await choose(t, 'Aceptada');
      await t.tap(find.text('Revisar cambio'));
      await t.pumpAndSettle();
      await t.tap(find.text('Confirmar cambio'));
      await t.pumpAndSettle();
      expect(repo.writes, 1);
      expect(repo.application.status, ApplicationStatus.accepted);
      expect(
        find.text(
          'Esta decisión es final. No hay cambios de estado disponibles.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Aviso interno enviado al candidato'),
        findsOneWidget,
      );
    },
  );
  testWidgets('lost response is resolved by GET and never another mutation', (
    t,
  ) async {
    final repo = await mount(t, lost: true);
    await choose(t, 'Rechazada');
    await t.tap(find.text('Revisar cambio'));
    await t.pumpAndSettle();
    await t.tap(find.text('Confirmar cambio'));
    await t.pumpAndSettle();
    expect(repo.writes, 1);
    expect(find.text('Comprobar cambio'), findsOneWidget);
    await t.tap(find.text('Comprobar cambio'));
    await t.pumpAndSettle();
    expect(repo.writes, 1);
    expect(repo.lookups, 1);
    expect(repo.application.status, ApplicationStatus.rejected);
    expect(find.text('Comprobar cambio'), findsNothing);
  });
  testWidgets(
    'conflict refreshes authoritative state and requires a new review',
    (t) async {
      final repo = await mount(t);
      repo.failure = const ApiFailure(
        'Actualiza: cambio concurrente',
        status: 409,
      );
      await choose(t, 'Aceptada');
      await t.tap(find.text('Revisar cambio'));
      await t.pumpAndSettle();
      await t.tap(find.text('Confirmar cambio'));
      await t.pumpAndSettle();
      expect(repo.writes, 1);
      expect(repo.application.statusVersion, 0);
      expect(find.text('Actualiza: cambio concurrente'), findsOneWidget);
      expect(find.text('Comprobar cambio'), findsNothing);
    },
  );
}
