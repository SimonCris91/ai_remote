import 'package:ai_remote/core/models/translation_direction.dart';
import 'package:ai_remote/voice/audio_capture_service.dart';

class TranslationRequest {
  const TranslationRequest({required this.direction, required this.audio});

  final TranslationDirection direction;
  final AudioCaptureResult audio;
}

class TranslationResult {
  const TranslationResult({
    required this.sourceTranscript,
    required this.translatedText,
  });

  final String sourceTranscript;
  final String translatedText;
}

abstract interface class TranslatorService {
  Future<TranslationResult> translateTurn(TranslationRequest request);
  Future<void> cancel();
}
