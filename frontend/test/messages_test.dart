import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/testing.dart';
import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/core/api/operation_id.dart';
import 'package:worknet/features/messages/domain/message.dart';
import 'package:worknet/features/messages/data/messages_repository.dart';
import 'package:worknet/features/messages/presentation/chat_page.dart';
import 'package:worknet/features/messages/presentation/conversations_page.dart';
import 'package:worknet/features/messages/presentation/message_access.dart';
import 'offer_search_test.dart' show candidateSession;
import 'support/access_fakes.dart' show jsonResponse;
import 'support/messages_fakes.dart';

Map<String, dynamic> conversationJson() => {
  'id': 1,
  'application_id': 5,
  'offer': {'id': 3, 'title': 'Backend QA', 'company_name': 'Empresa QA'},
  'contact': {'id': 2, 'full_name': 'Empresa QA', 'role': 'empresa'},
  'unread_count': 1,
  'last_activity_at': '2026-11-08T20:00:00Z',
  'last_message': 'Hola',
};
Map<String, dynamic> messageJson(
  String key, {
  int id = 1,
  String text = 'Hola',
}) => {
  'id': id,
  'conversation_id': 1,
  'sender_id': 1,
  'recipient_id': 2,
  'client_message_id': key,
  'text': text,
  'created_at': '2026-11-08T20:00:00Z',
  'read_at': null,
};
Map<String, dynamic> pageJson(String key, List<dynamic> rows) => {
  'count': rows.length,
  'page': 1,
  'page_size': 10,
  'total_pages': rows.isEmpty ? 0 : 1,
  'next_page': null,
  'previous_page': null,
  key: rows,
};

void main() {
  test(
    'HTTP context and search use canonical application and retain literal query',
    () async {
      final calls = <Uri>[];
      final api = WorkNetApi(
        client: MockClient((r) async {
          calls.add(r.url);
          expect(r.headers['Authorization'], 'Token qa-private');
          if (r.method == 'POST') {
            expect(jsonDecode(r.body), {'application_id': 5});
            return jsonResponse({
              'conversation': conversationJson(),
              'created': true,
            }, 201);
          }
          return jsonResponse(pageJson('conversations', [conversationJson()]));
        }),
      );
      final repo = HttpMessagesRepository(api);
      expect((await repo.start('qa-private', 5)).contactId, 2);
      expect(
        (await repo.conversations('qa-private', query: 'QA & oferta')).count,
        1,
      );
      expect(calls.last.queryParameters['q'], 'QA & oferta');
      expect(calls.last.queryParameters['page_size'], '10');
    },
  );
  test(
    'message windows preserve anchor and reject duplicate or unrelated receipts',
    () async {
      final key = newOperationId();
      var corrupt = false;
      final api = WorkNetApi(
        client: MockClient((r) async {
          if (r.url.path.contains('messages')) {
            expect(r.url.queryParameters['through_id'], '2');
            return jsonResponse({
              ...pageJson('messages', [
                messageJson(key),
                messageJson(newOperationId(), id: corrupt ? 1 : 2),
              ]),
              'conversation': conversationJson(),
              'through_id': 2,
              'order': 'latest_windows_chronological',
            });
          }
          return jsonResponse({'unread_count': 1});
        }),
      );
      final repo = HttpMessagesRepository(api);
      expect(
        (await repo.messages(
          'qa-private',
          1,
          throughId: 2,
        )).rows.map((m) => m.id),
        [1, 2],
      );
      corrupt = true;
      await expectLater(
        repo.messages('qa-private', 1, throughId: 2),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
  test(
    'text receipt and read acknowledgment validate exactly the pending intent',
    () async {
      final draft = MessageDraft(id: newOperationId(), text: 'Hola');
      var bad = false;
      final repo = HttpMessagesRepository(
        WorkNetApi(
          client: MockClient((r) async {
            if (r.url.path.endsWith('read/')) {
              expect(jsonDecode(r.body), {
                'message_ids': [4, 6],
              });
              return jsonResponse({'marked_read': 2, 'unread_count': 1});
            }
            if (r.method == 'POST') {
              expect(jsonDecode(r.body), {
                'text': 'Hola',
                'client_message_id': draft.id,
              });
            }
            return jsonResponse({
              'created': r.method == 'POST',
              'message': messageJson(bad ? newOperationId() : draft.id),
            });
          }),
        ),
      );
      expect((await repo.send('qa-private', 1, draft)).text, 'Hola');
      expect((await repo.lookup('qa-private', 1, draft)).clientId, draft.id);
      expect(await repo.read('qa-private', 1, [4, 6]), 1);
      bad = true;
      await expectLater(
        repo.send('qa-private', 1, draft),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
  Future<void> tap(WidgetTester t, Finder finder) async {
    await t.ensureVisible(finder);
    await t.tap(finder);
    await t.pumpAndSettle();
  }

  Future<void> chat(
    WidgetTester t,
    MessagesFake repo, {
    bool mobile = false,
  }) async {
    t.view.physicalSize = mobile
        ? const Size(390, 844)
        : const Size(1100, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final session = await candidateSession();
    await t.pumpWidget(
      MaterialApp(
        home: ChatPage(session: session, repository: repo, id: 1),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'mobile shows both directions dates and only reads the presented incoming IDs',
    (t) async {
      final repo = MessagesFake()..insertDuringRead = true;
      await chat(t, repo, mobile: true);
      expect(repo.acks.first, [1]);
      expect(repo.pending, 1);
      expect(find.text('Tú · Enviado'), findsOneWidget);
      expect(find.text('Empresa ficticia QA · Recibido'), findsOneWidget);
      expect(
        find.text('Pendientes de lectura en esta conversación: 1'),
        findsOneWidget,
      );
      expect(find.text('Nuevo durante lectura'), findsNothing);
      await tap(t, find.text('Actualizar conversación'));
      expect(repo.pending, 0);
      expect(find.text('Nuevo durante lectura'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'empty text is rejected and same legitimate text can be sent twice',
    (t) async {
      final repo = MessagesFake(seed: false);
      await chat(t, repo);
      await tap(t, find.text('Enviar mensaje'));
      expect(repo.attempts, isEmpty);
      expect(
        find.text('Escribe un mensaje de 1 a 4000 caracteres.'),
        findsOneWidget,
      );
      for (var i = 0; i < 2; i++) {
        await t.enterText(find.byType(TextField), 'Texto legítimo');
        await tap(t, find.text('Enviar mensaje'));
      }
      expect(repo.attempts.length, 2);
      expect(repo.attempts[0].id, isNot(repo.attempts[1].id));
      expect(repo.rows.length, 2);
    },
  );
  testWidgets('lost response is reconciled by GET without another send', (
    t,
  ) async {
    final repo = MessagesFake()..loseResponse = true;
    await chat(t, repo);
    await t.enterText(find.byType(TextField), 'Envío con respuesta perdida');
    await tap(t, find.text('Enviar mensaje'));
    expect(repo.attempts.length, 1);
    expect(find.text('Comprobar envío'), findsOneWidget);
    await tap(t, find.text('Comprobar envío'));
    expect(repo.lookups, 1);
    expect(repo.attempts.length, 1);
    expect(find.text('Envío con respuesta perdida'), findsOneWidget);
    expect(find.text('Comprobar envío'), findsNothing);
  });
  testWidgets('request lost before writing retries with exactly the same key', (
    t,
  ) async {
    final repo = MessagesFake()..failBefore = true;
    await chat(t, repo);
    await t.enterText(find.byType(TextField), 'Mismo intento');
    await tap(t, find.text('Enviar mensaje'));
    await tap(t, find.text('Comprobar envío'));
    expect(repo.lookups, 1);
    expect(repo.attempts.length, 1);
    repo.failBefore = false;
    await tap(t, find.text('Reintentar mismo envío'));
    expect(repo.attempts.length, 2);
    expect(repo.attempts[0].id, repo.attempts[1].id);
    expect(repo.rows.where((m) => m.text == 'Mismo intento').length, 1);
  });
  testWidgets('read failures preserve unread and allow idempotent retry', (
    t,
  ) async {
    final repo = MessagesFake()
      ..readFailure = const ApiFailure('Red de lectura', status: 503);
    await chat(t, repo);
    expect(repo.pending, 1);
    expect(find.textContaining('Lectura sin confirmar'), findsOneWidget);
    repo.readFailure = null;
    await tap(t, find.text('Reintentar lectura'));
    expect(repo.pending, 0);
    expect(repo.acks, [
      [1],
      [1],
    ]);
    expect(repo.attempts, isEmpty);
  });
  testWidgets(
    'conversation search keeps query on next page and resets on change',
    (t) async {
      final session = await candidateSession(),
          repo = MessagesFake()..conversationCount = 13;
      final router = GoRouter(
        initialLocation: '/messages?q=QA',
        routes: [
          GoRoute(
            path: '/messages',
            builder: (_, s) => ConversationsPage(
              key: ValueKey(s.uri),
              session: session,
              repository: repo,
              query: s.uri.queryParameters['q'] ?? '',
              page: int.tryParse(s.uri.queryParameters['page'] ?? '1') ?? 1,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      await tap(t, find.text('Más conversaciones'));
      expect(repo.queries.last, ('QA', 2));
      await t.enterText(find.byType(TextField), 'vacío');
      await tap(t, find.widgetWithText(FilledButton, 'Buscar conversaciones'));
      expect(repo.queries.last, ('vacío', 1));
      expect(
        find.textContaining('No hay conversaciones para esta búsqueda.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'dashboard pending count updates after returning from a read conversation',
    (t) async {
      final session = await candidateSession(), repo = MessagesFake();
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => Scaffold(
              body: MessagesEntry(session: session, repository: repo),
            ),
          ),
          GoRoute(
            path: '/messages',
            builder: (_, _) =>
                ChatPage(session: session, repository: repo, id: 1),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      expect(find.text('Mensajes sin leer: 1'), findsOneWidget);
      await tap(t, find.text('Mensajes'));
      expect(repo.pending, 0);
      await tap(t, find.text('Volver a conversaciones'));
      expect(find.text('Mensajes sin leer: 0'), findsOneWidget);
      // Expire while mounted: private conversations and composer are not retained.
      await session.expire();
      await t.pumpAndSettle();
      expect(find.text('Mensajes sin leer: 1'), findsNothing);
      expect(find.text('Mensajes sin leer: 0'), findsNothing);
    },
  );
  testWidgets(
    'production list back refreshes dashboard pending count after chat read',
    (t) async {
      final session = await candidateSession(), repo = MessagesFake();
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => Scaffold(
              body: MessagesEntry(session: session, repository: repo),
            ),
          ),
          GoRoute(
            path: '/messages',
            builder: (_, _) =>
                ConversationsPage(session: session, repository: repo),
          ),
          GoRoute(
            path: '/messages/:id',
            builder: (_, _) =>
                ChatPage(session: session, repository: repo, id: 1),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      expect(find.text('Mensajes sin leer: 1'), findsOneWidget);
      await tap(t, find.text('Mensajes'));
      await tap(t, find.text('Abrir conversación'));
      expect(repo.pending, 0);
      await tap(t, find.text('Volver a conversaciones'));
      await tap(t, find.text('Volver al dashboard'));
      expect(find.text('Mensajes sin leer: 0'), findsOneWidget);
      // The same back action also supports a direct URL without a push stack.
      router.go('/messages');
      await t.pumpAndSettle();
      expect(router.canPop(), isFalse);
      await tap(t, find.text('Volver al dashboard'));
      expect(router.routeInformationProvider.value.uri.path, '/dashboard');
    },
  );
  testWidgets(
    'a covered chat never acknowledges unseen arrivals and refreshes on return',
    (t) async {
      final session = await candidateSession(), repo = MessagesFake();
      final observer = RouteObserver<ModalRoute<dynamic>>();
      final router = GoRouter(
        initialLocation: '/chat',
        observers: [observer],
        routes: [
          GoRoute(
            path: '/chat',
            builder: (_, _) => ChatPage(
              session: session,
              repository: repo,
              id: 1,
              routeObserver: observer,
            ),
          ),
          GoRoute(
            path: '/cover',
            builder: (_, _) =>
                const Scaffold(body: Text('Detalle encima del chat')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();
      final previousAcks = repo.acks.length;
      repo.incoming('Nuevo no consultado');
      repo.loadGate = Completer<void>();
      await t.ensureVisible(find.text('Actualizar conversación'));
      await t.tap(find.text('Actualizar conversación'));
      await t.pump();
      router.push('/cover');
      await t.pump(const Duration(milliseconds: 500));
      repo.loadGate!.complete();
      await t.pumpAndSettle();
      expect(repo.acks.length, previousAcks);
      expect(repo.pending, 1);
      router.pop();
      await t.pumpAndSettle();
      expect(repo.acks.length, previousAcks + 1);
      expect(repo.pending, 0);
      expect(find.text('Nuevo no consultado'), findsOneWidget);
    },
  );
  testWidgets('an old read response does not overwrite a new visible window', (
    t,
  ) async {
    final session = await candidateSession(),
        repo = MessagesFake()..readGate = Completer<void>();
    final observer = RouteObserver<ModalRoute<dynamic>>();
    final router = GoRouter(
      initialLocation: '/chat',
      observers: [observer],
      routes: [
        GoRoute(
          path: '/chat',
          builder: (_, _) => ChatPage(
            session: session,
            repository: repo,
            id: 1,
            routeObserver: observer,
          ),
        ),
        GoRoute(
          path: '/cover',
          builder: (_, _) =>
              const Scaffold(body: Text('Detalle encima del chat')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    expect(repo.acks, [
      [1],
    ]);
    router.push('/cover');
    await t.pumpAndSettle();
    repo.incoming('Llegó con lectura anterior en vuelo');
    repo.loadGate = Completer<void>();
    router.pop();
    await t.pump();
    repo.loadGate!.complete();
    await t.idle();
    expect(repo.acks.length, 1);
    repo.readGate!.complete();
    await t.idle();
    // La carga ya terminó, pero todavía no hubo frame de la nueva ventana.
    expect(repo.acks.length, 1);
    expect(repo.pending, 1);
    await t.pumpAndSettle();
    expect(repo.acks, [
      [1],
      [1, 3],
    ]);
    expect(repo.pending, 0);
    expect(
      find.text('Pendientes de lectura en esta conversación: 0'),
      findsOneWidget,
    );
  });
}
