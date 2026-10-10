import 'package:ai_remote/core/models/channel.dart';
import 'package:ai_remote/core/models/conversation_message.dart';
import 'package:ai_remote/core/models/translation_direction.dart';
import 'package:ai_remote/voice/audio_capture_service.dart';

enum VoiceBackendTarget { openai, codex }

class VoiceTurnRequest {
  const VoiceTurnRequest({
    required this.channel,
    required this.history,
    required this.audio,
    this.backendTarget = VoiceBackendTarget.openai,
    this.codexThreadId,
  });

  final Channel channel;
  final List<ConversationMessage> history;
  final AudioCaptureResult audio;
  final VoiceBackendTarget backendTarget;
  final String? codexThreadId;
}

class TextTurnRequest {
  const TextTurnRequest({
    required this.channel,
    required this.text,
    required this.history,
    this.backendTarget = VoiceBackendTarget.openai,
    this.codexThreadId,
    this.translationDirection,
  });

  final Channel channel;
  final String text;
  final List<ConversationMessage> history;
  final VoiceBackendTarget backendTarget;
  final String? codexThreadId;
  final TranslationDirection? translationDirection;
}

class VoiceTurnResult {
  const VoiceTurnResult({
    required this.transcript,
    required this.responseText,
    this.codexThreadId,
  });

  final String transcript;
  final String responseText;
  final String? codexThreadId;
}

abstract interface class VoiceEngine {
  bool get supportsContinuousMode;
  Future<VoiceTurnResult> processPushToTalkTurn(VoiceTurnRequest request);
  Future<VoiceTurnResult> processTextTurn(TextTurnRequest request);
  Future<void> cancel();
  Future<void> dispose();
}
