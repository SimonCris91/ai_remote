import 'package:ai_remote/core/models/conversation_message.dart';

class ConversationSession {
  ConversationSession({required this.channelId});

  final String channelId;
  String? codexThreadId;
  final List<ConversationMessage> _messages = <ConversationMessage>[];

  List<ConversationMessage> get messages => List.unmodifiable(_messages);

  void add(ConversationMessage message) => _messages.add(message);

  void addAll(Iterable<ConversationMessage> messages) =>
      _messages.addAll(messages);

  void clear() => _messages.clear();
}
