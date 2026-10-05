import 'package:ai_remote/core/state/ai_remote_state.dart';
import 'package:flutter/material.dart';

class StateBadge extends StatelessWidget {
  const StateBadge({super.key, required this.state});

  final AiRemoteState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      AiRemoteState.listening => const Color(0xFF63E6BE),
      AiRemoteState.processing ||
      AiRemoteState.translating => const Color(0xFFFFC857),
      AiRemoteState.aiSpeaking => const Color(0xFF7AA2FF),
      AiRemoteState.error ||
      AiRemoteState.disconnected => const Color(0xFFFF6B6B),
      _ => const Color(0xFF93A4BC),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              state.label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
