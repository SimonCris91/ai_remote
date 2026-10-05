import 'package:ai_remote/core/models/conversation_message.dart';
import 'package:ai_remote/core/models/conversation_session.dart';
import 'package:flutter/material.dart';

class ConversationPanel extends StatelessWidget {
  const ConversationPanel({super.key, required this.session});

  final ConversationSession session;

  @override
  Widget build(BuildContext context) {
    final messages = session.messages.reversed
        .take(4)
        .toList()
        .reversed
        .toList();
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101827).withValues(alpha: 0.82),
        border: Border.all(color: const Color(0xFF24344C)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: messages.isEmpty
          ? const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum_outlined, color: Color(0xFF667892)),
                SizedBox(height: 10),
                Text(
                  'Nessun turno in questo canale',
                  style: TextStyle(color: Color(0xFF8FA1BA)),
                ),
              ],
            )
          : Column(
              children: [
                for (final message in messages) _MessageRow(message: message),
              ],
            ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});

  final ConversationMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ConversationRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isUser ? Icons.mic_none_rounded : Icons.auto_awesome_rounded,
            size: 17,
            color: isUser ? const Color(0xFF63E6BE) : const Color(0xFF7AA2FF),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFD7E1EE),
                height: 1.35,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
