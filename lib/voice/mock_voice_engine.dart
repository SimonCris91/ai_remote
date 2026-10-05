import 'package:ai_remote/core/models/channel_type.dart';
import 'package:ai_remote/voice/voice_engine.dart';

class MockVoiceEngine implements VoiceEngine {
  MockVoiceEngine({this.latency = const Duration(milliseconds: 650)});

  final Duration latency;
  int _turn = 0;

  @override
  bool get supportsContinuousMode => false;

  @override
  Future<VoiceTurnResult> processPushToTalkTurn(
    VoiceTurnRequest request,
  ) async {
    await Future<void>.delayed(latency);
    _turn += 1;
    final previousTurns = request.history
        .where((message) => message.role.name == 'user')
        .length;
    final transcript = request.channel.type == ChannelType.agent
        ? 'Richiesta tecnica simulata ${previousTurns + 1}'
        : 'Messaggio vocale simulato ${previousTurns + 1}';
    final duration = request.audio.duration.inMilliseconds < 250
        ? 'un tocco rapido'
        : '${request.audio.duration.inSeconds.clamp(1, 99)} secondi di voce';
    final response = request.channel.type == ChannelType.agent
        ? 'Canale tecnico attivo. Ho ricevuto $duration. Nel collegamento live '
              'qui arriverà una risposta tecnica basata sul contesto di questo '
              'canale.'
        : 'Turno $_turn ricevuto: $duration. Il contesto di General Chat resta '
              'separato dagli altri canali.';
    return VoiceTurnResult(transcript: transcript, responseText: response);
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}
