enum VoiceInteractionMode { pushToTalk, continuous }

class VoiceSession {
  VoiceSession({
    required this.channelId,
    required this.mode,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  final String channelId;
  final VoiceInteractionMode mode;
  final DateTime startedAt;
}
