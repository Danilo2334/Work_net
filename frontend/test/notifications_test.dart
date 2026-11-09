import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/access/presentation/session_controller.dart';
import 'package:worknet/features/notifications/notifications_repository.dart';
import 'package:worknet/features/notifications/notifications_page.dart';
import 'offer_search_test.dart' show candidateSession;
import 'messages_test.dart' show pageJson;
import 'support/access_fakes.dart' show jsonResponse;

class NoticesFake implements NotificationsRepository {
  bool readAlready = false, empty = false;
  ApiFailure? failure;
  Completer<NoticePage>? delayed;
  final calls = <({int page, String status, int? anchor})>[];
  final readIds = <int>[];
  Map<String, bool> prefs = {for (final k in noticeLabels.keys) k: true};
  Map<String, bool>? saved;
  int preferenceCalls = 0;
  AccountNotice notice(int id) => AccountNotice(
    id: id,
    title: 'Aviso privado QA $id',
    kind: 'message_received',
    createdAt: DateTime.utc(2026, 11, 8, 20),
    readAt: readAlready ? DateTime.utc(2026, 11, 8, 21) : null,
    conversationId: 3,
  );
  @override
  Future<NoticePage> list(
    String token, {
    int page = 1,
    String status = 'all',
    int? anchor,
  }) async {
    calls.add((page: page, status: status, anchor: anchor));
    if (failure case final e?) throw e;
    return delayed?.future ??
        NoticePage(
          rows: empty ? [] : [notice(page)],
          count: empty ? 0 : 2,
          page: page,
          pages: empty ? 0 : 2,
          anchor: 17,
          unread: readAlready ? 0 : 1,
        );
  }

  @override
  Future<int> summary(String token) async => readAlready ? 0 : 1;
  @override
  Future<void> read(String token, int id) async {
    readIds.add(id);
    readAlready = true;
  }

  @override
  Future<Map<String, bool>> preferences(String token) async {
    preferenceCalls++;
    return Map.of(prefs);
  }

  @override
  Future<Map<String, bool>> savePreferences(
    String token,
    Map<String, bool> values,
  ) async {
    saved = Map.of(values);
    prefs = Map.of(values);
    return Map.of(values);
  }
}

Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<SessionController> showNotices(
  WidgetTester t,
  NoticesFake repo, {
  bool mobile = false,
}) async {
  t.view.physicalSize = mobile ? const Size(390, 844) : const Size(1440, 1100);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final session = await candidateSession();
  await t.pumpWidget(
    MaterialApp(
      home: NotificationsPage(session: session, repository: repo),
    ),
  );
  await t.pumpAndSettle();
  return session;
}

void main() {
  test(
    'HTTP preserves filters anchor authorization and exact read IDs',
    () async {
      final requests = <String>[];
      final repo = HttpNotificationsRepository(
        WorkNetApi(
          client: MockClient((r) async {
            expect(r.headers['Authorization'], 'Token qa-private');
            requests.add('${r.method} ${r.url.path}');
            if (r.url.path.endsWith('/read/')) {
              expect(jsonDecode(r.body), {
                'notification_ids': [3],
              });
              return jsonResponse({'marked_read': 1, 'unread_count': 0});
            }
            if (r.url.path.endsWith('/preferences/')) {
              return jsonResponse({
                'preferences': {for (final k in noticeLabels.keys) k: true},
              });
            }
            if (r.url.path.endsWith('/summary/')) {
              return jsonResponse({'unread_count': 1});
            }
            expect(r.url.queryParameters, {
              'page': '1',
              'page_size': '10',
              'status': 'unread',
              'through_id': '3',
            });
            return jsonResponse({
              ...pageJson('notifications', [
                {
                  'id': 3,
                  'title': 'Aviso QA',
                  'event_kind': 'message_received',
                  'created_at': '2026-11-08T20:00:00Z',
                  'read_at': null,
                  'conversation_id': 2,
                },
              ]),
              'through_id': 3,
              'unread_count': 1,
            });
          }),
        ),
      );
      expect(
        (await repo.list(
          'qa-private',
          status: 'unread',
          anchor: 3,
        )).rows.single.conversationId,
        2,
      );
      await repo.read('qa-private', 3);
      expect(await repo.summary('qa-private'), 1);
      expect(
        (await repo.savePreferences('qa-private', {
          'message_received': false,
        })).length,
        4,
      );
      expect(requests.length, 4);
    },
  );
  test(
    'malformed lists and preference values become recoverable failures',
    () async {
      final repo = HttpNotificationsRepository(
        WorkNetApi(
          client: MockClient(
            (_) async => jsonResponse({
              'notifications': [],
              'preferences': {'message_received': 'false'},
            }),
          ),
        ),
      );
      await expectLater(repo.list('qa'), throwsA(isA<ApiFailure>()));
      await expectLater(repo.preferences('qa'), throwsA(isA<ApiFailure>()));
    },
  );
  testWidgets(
    'desktop does not read implicitly and explicitly refreshes count',
    (t) async {
      final repo = NoticesFake();
      await showNotices(t, repo);
      expect(find.text('Aviso privado QA 1'), findsOneWidget);
      expect(repo.readIds, isEmpty);
      await tap(t, find.text('Marcar como leída'));
      expect(repo.readIds, [1]);
      expect(find.text('Notificaciones pendientes: 0'), findsOneWidget);
      expect(find.text('Notificación marcada como leída.'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'mobile edits future preferences explicitly without changing history',
    (t) async {
      final repo = NoticesFake();
      await showNotices(t, repo, mobile: true);
      await tap(t, find.widgetWithText(SwitchListTile, 'Nuevos mensajes'));
      expect(repo.saved, isNull);
      await tap(t, find.text('Guardar preferencias'));
      expect(repo.saved!['message_received'], false);
      expect(repo.readIds, isEmpty);
      expect(
        find.text('Preferencias guardadas para los eventos nuevos.'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'pagination retains anchor and changing filter resets first page',
    (t) async {
      final repo = NoticesFake();
      await showNotices(t, repo);
      await tap(t, find.text('Página siguiente'));
      expect(repo.calls.last, (page: 2, status: 'all', anchor: 17));
      await tap(t, find.byType(DropdownButtonFormField<String>));
      await tap(t, find.text('Pendientes').last);
      expect(repo.calls.last, (page: 1, status: 'unread', anchor: null));
    },
  );
  testWidgets('empty data and load errors have retry', (t) async {
    final repo = NoticesFake()
      ..failure = const ApiFailure('Fallo QA controlado');
    await showNotices(t, repo);
    expect(find.text('Fallo QA controlado'), findsOneWidget);
    repo.failure = null;
    repo.empty = true;
    await tap(t, find.text('Reintentar'));
    expect(
      find.text('No hay notificaciones para este filtro.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'expired session discards late data and does not fetch private preferences',
    (t) async {
      final repo = NoticesFake()..delayed = Completer<NoticePage>();
      final session = await candidateSession();
      await t.pumpWidget(
        MaterialApp(
          home: NotificationsPage(session: session, repository: repo),
        ),
      );
      await t.pump();
      await session.expire();
      repo.delayed!.complete(
        NoticePage(
          rows: [repo.notice(1)],
          count: 1,
          page: 1,
          pages: 1,
          anchor: 1,
          unread: 1,
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Aviso privado QA 1'), findsNothing);
      expect(repo.preferenceCalls, 0);
      expect(find.byType(SwitchListTile), findsNothing);
    },
  );
  testWidgets(
    'production centre back completes entry and updates unread1 to0',
    (t) async {
      t.view.physicalSize = const Size(1440, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repo = NoticesFake(), session = await candidateSession();
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => Scaffold(
              body: NotificationsEntry(session: session, repository: repo),
            ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) =>
                NotificationsPage(session: session, repository: repo),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      expect(find.text('Avisos pendientes: 1'), findsOneWidget);
      await tap(t, find.text('Notificaciones'));
      await tap(t, find.text('Marcar como leída'));
      await tap(t, find.text('Volver al dashboard'));
      expect(find.text('Avisos pendientes: 0'), findsOneWidget);
      router.go('/notifications');
      await t.pumpAndSettle();
      await tap(t, find.text('Volver al dashboard'));
      expect(router.routeInformationProvider.value.uri.path, '/dashboard');
    },
  );
}
