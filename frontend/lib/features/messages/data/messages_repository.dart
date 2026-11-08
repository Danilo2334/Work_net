import 'package:worknet/core/api/worknet_api.dart';
import 'package:worknet/features/offers/data/offer_parser.dart'
    show validatePage;
import '../domain/message.dart';

class HttpMessagesRepository implements MessagesRepository {
  HttpMessagesRepository(this.api);
  final WorkNetApi api;
  T _parse<T>(T Function() action) {
    try {
      return action();
    } on Object catch (e) {
      if (e is! FormatException &&
          e is! TypeError &&
          e is! RangeError &&
          e is! StateError) {
        rethrow;
      }
      throw const ApiFailure(
        'No pudimos leer la conversación. Comprueba los datos antes de volver a enviar.',
      );
    }
  }

  int _number(dynamic value, {bool zero = false}) {
    if (value is! int || value < (zero ? 0 : 1)) throw const FormatException();
    return value;
  }

  SelectionConversation _conversation(dynamic value) {
    final v = value as Map<String, dynamic>,
        c = v['contact'] as Map<String, dynamic>,
        o = v['offer'] as Map<String, dynamic>;
    if (!['candidato', 'empresa'].contains(c['role'])) {
      throw const FormatException();
    }
    return SelectionConversation(
      id: _number(v['id']),
      applicationId: _number(v['application_id']),
      offerId: _number(o['id']),
      offerTitle: o['title'] as String,
      company: o['company_name'] as String,
      contactId: _number(c['id']),
      contactName: c['full_name'] as String,
      contactRole: c['role'] as String,
      unread: _number(v['unread_count'], zero: true),
      activityAt: DateTime.parse(v['last_activity_at'] as String),
      lastText: v['last_message'] as String?,
    );
  }

  SelectionMessage _message(dynamic value) {
    final v = value as Map<String, dynamic>;
    final message = SelectionMessage(
      id: _number(v['id']),
      conversationId: _number(v['conversation_id']),
      senderId: _number(v['sender_id']),
      recipientId: _number(v['recipient_id']),
      clientId: v['client_message_id'] as String,
      text: v['text'] as String,
      createdAt: DateTime.parse(v['created_at'] as String),
      readAt: v['read_at'] == null
          ? null
          : DateTime.parse(v['read_at'] as String),
    );
    if (message.senderId == message.recipientId ||
        message.text.trim().isEmpty ||
        message.text.runes.length > 4000 ||
        !RegExp(
          r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
        ).hasMatch(message.clientId)) {
      throw const FormatException();
    }
    return message;
  }

  @override
  Future<int> unread(String token) async {
    final r = await api.request('messages/summary/', token: token);
    return _parse(() => _number(r['unread_count'], zero: true));
  }

  @override
  Future<ConversationPage> conversations(
    String token, {
    String query = '',
    int page = 1,
  }) async {
    final uri = Uri(
      path: 'conversations/',
      queryParameters: {'q': query, 'page': '$page', 'page_size': '10'},
    );
    final r = await api.request(uri.toString(), token: token);
    return _parse(() {
      final rows = (r['conversations'] as List).map(_conversation).toList();
      validatePage(r, page, rows.length);
      if (rows.map((x) => x.id).toSet().length != rows.length) {
        throw const FormatException();
      }
      return ConversationPage(
        rows: rows,
        count: r['count'] as int,
        page: page,
        pages: r['total_pages'] as int,
        next: r['next_page'] as int?,
        previous: r['previous_page'] as int?,
      );
    });
  }

  @override
  Future<SelectionConversation> start(String token, int applicationId) async {
    final r = await api.request(
      'conversations/',
      token: token,
      data: {'application_id': applicationId},
    );
    return _parse(() {
      final c = _conversation(r['conversation']);
      if (c.applicationId != applicationId || r['created'] is! bool) {
        throw const FormatException();
      }
      return c;
    });
  }

  @override
  Future<MessagePage> messages(
    String token,
    int conversationId, {
    int page = 1,
    int? throughId,
  }) async {
    final uri = Uri(
      path: 'conversations/$conversationId/messages/',
      queryParameters: {
        'page': '$page',
        'page_size': '10',
        if (throughId != null) 'through_id': '$throughId',
      },
    );
    final r = await api.request(uri.toString(), token: token);
    return _parse(() {
      final conversation = _conversation(r['conversation']),
          rows = (r['messages'] as List).map(_message).toList();
      final anchor = _number(r['through_id'], zero: true);
      validatePage(r, page, rows.length);
      if (r['order'] != 'latest_windows_chronological' ||
          conversation.id != conversationId ||
          (throughId != null && anchor != throughId) ||
          rows.any(
            (m) => m.conversationId != conversationId || m.id > anchor,
          ) ||
          rows.map((x) => x.id).toSet().length != rows.length) {
        throw const FormatException();
      }
      for (var i = 1; i < rows.length; i++) {
        if (rows[i - 1].id >= rows[i].id) throw const FormatException();
      }
      return MessagePage(
        conversation: conversation,
        rows: rows,
        count: r['count'] as int,
        page: page,
        pages: r['total_pages'] as int,
        throughId: anchor,
        next: r['next_page'] as int?,
        previous: r['previous_page'] as int?,
      );
    });
  }

  Future<SelectionMessage> _receipt(
    Future<Map<String, dynamic>> response,
    int id,
    MessageDraft draft,
  ) async {
    final r = await response;
    return _parse(() {
      final m = _message(r['message']);
      if (m.conversationId != id ||
          m.clientId != draft.id ||
          m.text != draft.text ||
          r['created'] is! bool) {
        throw const FormatException();
      }
      return m;
    });
  }

  @override
  Future<SelectionMessage> send(
    String token,
    int conversationId,
    MessageDraft draft,
  ) => _receipt(
    api.request(
      'conversations/$conversationId/messages/',
      token: token,
      data: {'text': draft.text, 'client_message_id': draft.id},
    ),
    conversationId,
    draft,
  );
  @override
  Future<SelectionMessage> lookup(
    String token,
    int conversationId,
    MessageDraft draft,
  ) => _receipt(
    api.request(
      'conversations/$conversationId/messages/operations/${draft.id}/',
      token: token,
    ),
    conversationId,
    draft,
  );
  @override
  Future<int> read(String token, int conversationId, List<int> ids) async {
    final r = await api.request(
      'conversations/$conversationId/read/',
      token: token,
      data: {'message_ids': ids},
    );
    return _parse(() {
      final n = _number(r['marked_read'], zero: true);
      if (n > ids.length) throw const FormatException();
      return _number(r['unread_count'], zero: true);
    });
  }
}
