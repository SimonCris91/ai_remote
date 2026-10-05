enum ConversationRole { user, assistant }

class ConversationMessage {
  ConversationMessage({
    required this.role,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final ConversationRole role;
  final String content;
  final DateTime createdAt;
}
