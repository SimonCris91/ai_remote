import 'package:ai_remote/core/models/channel.dart';
import 'package:ai_remote/core/models/conversation_message.dart';
import 'package:ai_remote/voice/audio_capture_service.dart';

class VoiceTurnRequest {
  const VoiceTurnRequest({
    required this.channel,
    required this.history,
    required this.audio,
  });

  final Channel channel;
  final List<ConversationMessage> history;
  final AudioCaptureResult audio;
}

class VoiceTurnResult {
  const VoiceTurnResult({required this.transcript, required this.responseText});

  final String transcript;
  final String responseText;
}

abstract interface class VoiceEngine {
  bool get supportsContinuousMode;
  Future<VoiceTurnResult> processPushToTalkTurn(VoiceTurnRequest request);
  Future<void> cancel();
  Future<void> dispose();
}
