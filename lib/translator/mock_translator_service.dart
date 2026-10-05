import 'package:ai_remote/translator/translator_service.dart';

class MockTranslatorService implements TranslatorService {
  MockTranslatorService({this.latency = const Duration(milliseconds: 550)});

  final Duration latency;

  @override
  Future<TranslationResult> translateTurn(TranslationRequest request) async {
    await Future<void>.delayed(latency);
    if (request.direction.sourceCode == 'it') {
      return const TranslationResult(
        sourceTranscript: 'Buongiorno, come stai?',
        translatedText: 'Good morning, how are you?',
      );
    }
    return const TranslationResult(
      sourceTranscript: 'Good morning, how are you?',
      translatedText: 'Buongiorno, come stai?',
    );
  }

  @override
  Future<void> cancel() async {}
}
