import 'package:ai_remote/core/models/conversation_message.dart';

/// Persistence boundary for local-first conversation history.
///
/// Implementations must not upload conversation content. A future web sync
/// should be a separate, explicitly authenticated and user-controlled service.
abstract interface class ConversationStore {
  Future<Map<String, List<ConversationMessage>>> readAllMessages();

  Future<Map<String, String>> readCodexThreadIds();

  Future<void> saveCodexThreadId(String channelId, String threadId);

  Future<void> appendMessages(
    String channelId,
    List<ConversationMessage> messages,
  );

  Future<void> deleteChannel(String channelId);
}

class MemoryConversationStore implements ConversationStore {
  final Map<String, List<ConversationMessage>> _messages = {};
  final Map<String, String> _threadIds = {};

  @override
  Future<Map<String, List<ConversationMessage>>> readAllMessages() async => {
    for (final entry in _messages.entries)
      entry.key: List<ConversationMessage>.unmodifiable(entry.value),
  };

  @override
  Future<Map<String, String>> readCodexThreadIds() async =>
      Map<String, String>.of(_threadIds);

  @override
  Future<void> saveCodexThreadId(String channelId, String threadId) async {
    _threadIds[channelId] = threadId;
  }

  @override
  Future<void> appendMessages(
    String channelId,
    List<ConversationMessage> messages,
  ) async {
    _messages.putIfAbsent(channelId, () => []).addAll(messages);
  }

  @override
  Future<void> deleteChannel(String channelId) async {
    _messages.remove(channelId);
    _threadIds.remove(channelId);
  }
}
