class SelectionConversation {
  const SelectionConversation({
    required this.id,
    required this.applicationId,
    required this.offerId,
    required this.offerTitle,
    required this.company,
    required this.contactId,
    required this.contactName,
    required this.contactRole,
    required this.unread,
    required this.activityAt,
    this.lastText,
  });
  final int id, applicationId, offerId, contactId, unread;
  final String offerTitle, company, contactName, contactRole;
  final DateTime activityAt;
  final String? lastText;
}

class SelectionMessage {
  const SelectionMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.recipientId,
    required this.clientId,
    required this.text,
    required this.createdAt,
    this.readAt,
  });
  final int id, conversationId, senderId, recipientId;
  final String clientId, text;
  final DateTime createdAt;
  final DateTime? readAt;
  bool between(int me, int contact) =>
      (senderId == me && recipientId == contact) ||
      (senderId == contact && recipientId == me);
}

class ConversationPage {
  const ConversationPage({
    required this.rows,
    required this.count,
    required this.page,
    required this.pages,
    this.next,
    this.previous,
  });
  final List<SelectionConversation> rows;
  final int count, page, pages;
  final int? next, previous;
}

class MessagePage {
  const MessagePage({
    required this.conversation,
    required this.rows,
    required this.count,
    required this.page,
    required this.pages,
    required this.throughId,
    this.next,
    this.previous,
  });
  final SelectionConversation conversation;
  final List<SelectionMessage> rows;
  final int count, page, pages, throughId;
  final int? next, previous;
}

class MessageDraft {
  const MessageDraft({required this.id, required this.text});
  final String id, text;
}

abstract interface class MessagesRepository {
  Future<int> unread(String token);
  Future<ConversationPage> conversations(
    String token, {
    String query = '',
    int page = 1,
  });
  Future<SelectionConversation> start(String token, int applicationId);
  Future<MessagePage> messages(
    String token,
    int conversationId, {
    int page = 1,
    int? throughId,
  });
  Future<SelectionMessage> send(
    String token,
    int conversationId,
    MessageDraft draft,
  );
  Future<SelectionMessage> lookup(
    String token,
    int conversationId,
    MessageDraft draft,
  );
  Future<int> read(String token, int conversationId, List<int> ids);
}
