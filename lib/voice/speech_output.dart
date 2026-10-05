import 'package:flutter_tts/flutter_tts.dart';

abstract interface class SpeechOutput {
  Future<void> speak(String text, {required String languageCode});
  Future<void> stop();
  Future<void> dispose();
}

class FlutterTtsSpeechOutput implements SpeechOutput {
  FlutterTtsSpeechOutput() : _tts = FlutterTts() {
    _tts.awaitSpeakCompletion(true);
  }

  final FlutterTts _tts;

  @override
  Future<void> speak(String text, {required String languageCode}) async {
    await _tts.setLanguage(_localeFor(languageCode));
    // Slightly faster than the Android default while staying intelligible.
    await _tts.setSpeechRate(0.55);
    await _tts.setVolume(1);
    await _tts.speak(text, focus: true);
  }

  String _localeFor(String code) => switch (code) {
    'it' => 'it-IT',
    'en' => 'en-US',
    'es' => 'es-ES',
    'fr' => 'fr-FR',
    'de' => 'de-DE',
    _ => code,
  };

  @override
  Future<void> stop() async => _tts.stop();

  @override
  Future<void> dispose() async => _tts.stop();
}

class SilentSpeechOutput implements SpeechOutput {
  @override
  Future<void> speak(String text, {required String languageCode}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
