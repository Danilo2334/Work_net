import 'dart:async';
import 'package:worknet/core/api/operation_id.dart';
import 'package:worknet/core/domain/failure.dart';
import 'package:worknet/features/messages/domain/message.dart';

class MessagesFake implements MessagesRepository {
  final rows = <SelectionMessage>[];
  final attempts = <MessageDraft>[];
  final queries = <(String, int)>[];
  final acks = <List<int>>[];
  int lookups = 0, conversationCount = 1;
  bool loseResponse = false, failBefore = false, insertDuringRead = false;
  ApiFailure? loadFailure, readFailure;
  Completer<void>? loadGate;
  Completer<void>? readGate;
  int get pending =>
      rows.where((m) => m.recipientId == 1 && m.readAt == null).length;
  MessagesFake({bool seed = true}) {
    if (seed) {
      incoming('Mensaje recibido QA');
      add('Mensaje enviado anterior', 1, 2);
    }
  }
  SelectionConversation conv([int id = 1]) => SelectionConversation(
    id: id,
    applicationId: 5,
    offerId: 3,
    offerTitle: 'Backend QA',
    company: 'Empresa ficticia QA',
    contactId: 2,
    contactName: 'Empresa ficticia QA',
    contactRole: 'empresa',
    unread: pending,
    activityAt: DateTime.utc(2026, 11, 8, 20),
    lastText: rows.isEmpty ? null : rows.last.text,
  );
  SelectionMessage add(String text, int sender, int recipient, {String? key}) {
    final m = SelectionMessage(
      id: rows.length + 1,
      conversationId: 1,
      senderId: sender,
      recipientId: recipient,
      clientId: key ?? newOperationId(),
      text: text,
      createdAt: DateTime.utc(2026, 11, 8, 20, rows.length),
    );
    rows.add(m);
    return m;
  }

  void incoming(String text) => add(text, 2, 1);
  @override
  Future<int> unread(String token) async => pending;
  @override
  Future<SelectionConversation> start(String token, int applicationId) async =>
      conv();
  @override
  Future<ConversationPage> conversations(
    String token, {
    String query = '',
    int page = 1,
  }) async {
    queries.add((query, page));
    if (loadFailure != null) throw loadFailure!;
    final count = query == 'vacío' ? 0 : conversationCount,
        pages = (count + 9) ~/ 10;
    return ConversationPage(
      rows: List.generate(
        count,
        (i) => conv(i + 1),
      ).skip((page - 1) * 10).take(10).toList(),
      count: count,
      page: page,
      pages: pages,
      next: page < pages ? page + 1 : null,
      previous: page > 1 ? page - 1 : null,
    );
  }

  @override
  Future<MessagePage> messages(
    String token,
    int conversationId, {
    int page = 1,
    int? throughId,
  }) async {
    if (loadFailure != null) throw loadFailure!;
    final anchor = throughId ?? (rows.isEmpty ? 0 : rows.last.id);
    final snapshot = rows.where((m) => m.id <= anchor).toList(),
        count = rows.where((m) => m.id <= anchor).length;
    final list = snapshot.reversed
            .skip((page - 1) * 10)
            .take(10)
            .toList()
            .reversed
            .toList(),
        pages = (count + 9) ~/ 10;
    final result = MessagePage(
      conversation: conv(),
      rows: list,
      count: count,
      page: page,
      pages: pages,
      throughId: anchor,
      next: page < pages ? page + 1 : null,
      previous: page > 1 ? page - 1 : null,
    );
    if (loadGate != null) await loadGate!.future;
    return result;
  }

  @override
  Future<SelectionMessage> send(
    String token,
    int conversationId,
    MessageDraft draft,
  ) async {
    attempts.add(draft);
    if (failBefore) throw const ApiFailure('Red antes del envío');
    final old = rows.where((m) => m.clientId == draft.id).firstOrNull;
    final msg = old ?? add(draft.text, 1, 2, key: draft.id);
    if (loseResponse) throw const ApiFailure('Respuesta perdida');
    return msg;
  }

  @override
  Future<SelectionMessage> lookup(
    String token,
    int conversationId,
    MessageDraft draft,
  ) async {
    lookups++;
    final m = rows.where((m) => m.clientId == draft.id).firstOrNull;
    if (m == null) throw const ApiFailure('Sin registro', status: 404);
    return m;
  }

  @override
  Future<int> read(String token, int conversationId, List<int> ids) async {
    acks.add(List.of(ids));
    if (readFailure != null) throw readFailure!;
    if (readGate != null) await readGate!.future;
    if (insertDuringRead) {
      insertDuringRead = false;
      incoming('Nuevo durante lectura');
    }
    for (var i = 0; i < rows.length; i++) {
      final m = rows[i];
      if (ids.contains(m.id) && m.recipientId == 1 && m.readAt == null) {
        rows[i] = SelectionMessage(
          id: m.id,
          conversationId: m.conversationId,
          senderId: m.senderId,
          recipientId: m.recipientId,
          clientId: m.clientId,
          text: m.text,
          createdAt: m.createdAt,
          readAt: DateTime.utc(2026, 11, 8, 21),
        );
      }
    }
    return pending;
  }
}
