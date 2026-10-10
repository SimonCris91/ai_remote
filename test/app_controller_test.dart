import 'package:ai_remote/channels/channel_manager.dart';
import 'package:ai_remote/core/app_controller.dart';
import 'package:ai_remote/core/models/remote_command.dart';
import 'package:ai_remote/core/state/ai_remote_state.dart';
import 'package:ai_remote/core/state/ai_remote_state_machine.dart';
import 'package:ai_remote/music/chord_analyzer.dart';
import 'package:ai_remote/music/chord_monitor.dart';
import 'package:ai_remote/music/system_audio_capture.dart';
import 'package:ai_remote/remote/remote_controller.dart';
import 'package:ai_remote/services/channel_selection_store.dart';
import 'package:ai_remote/translator/mock_translator_service.dart';
import 'package:ai_remote/voice/mock_voice_engine.dart';
import 'package:ai_remote/voice/voice_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  test(
    'typed message gets a mock reply and enters the channel history',
    () async {
      final controller = AppController(
        channelManager: ChannelManager(
          selectionStore: MemoryChannelSelectionStore(),
        ),
        stateMachine: AiRemoteStateMachine(),
        voiceEngine: MockVoiceEngine(latency: Duration.zero),
        translatorService: MockTranslatorService(latency: Duration.zero),
        audioCapture: FakeAudioCaptureService(),
        speechOutput: RecordingSpeechOutput(),
      );
      await controller.initialize();

      expect(await controller.sendTextMessage('  Ciao AI Remote  '), isTrue);
      expect(controller.state, AiRemoteState.channelSelected);
      expect(controller.selectedSession.messages, hasLength(2));
      expect(
        controller.selectedSession.messages.first.content,
        'Ciao AI Remote',
      );
      expect(
        controller.selectedSession.messages.last.content,
        contains('[MOCK]'),
      );
    },
  );

  test('Codex Developer requires a one-turn approval from the phone', () async {
    final engine = FakeLiveVoiceEngine();
    final controller = AppController(
      channelManager: ChannelManager(
        selectionStore: MemoryChannelSelectionStore(
          selectedChannelId: 'codex-developer',
        ),
      ),
      stateMachine: AiRemoteStateMachine(),
      voiceEngine: engine,
      translatorService: MockTranslatorService(latency: Duration.zero),
      audioCapture: FakeAudioCaptureService(),
      speechOutput: RecordingSpeechOutput(),
      codexChannelIds: const {'codex-developer'},
    );
    await controller.initialize();

    expect(controller.codexDeveloperReady, isTrue);
    expect(await controller.sendTextMessage('Modifica il progetto'), isFalse);
    expect(controller.state, AiRemoteState.error);
    expect(engine.textRequests, isEmpty);

    await controller.cancelCurrentInteraction();
    controller.authorizeNextCodexTurn();
    expect(controller.codexTurnConsentActive, isTrue);
    expect(await controller.sendTextMessage('Modifica il progetto'), isTrue);
    expect(engine.textRequests.single.backendTarget, VoiceBackendTarget.codex);
    expect(controller.codexTurnConsentActive, isFalse);
    expect(await controller.sendTextMessage('Altro turno'), isFalse);
    expect(engine.textRequests, hasLength(1));
  });

  test(
    'watch push-to-talk cannot start a Codex turn without phone approval',
    () async {
      final audio = FakeAudioCaptureService();
      final engine = FakeLiveVoiceEngine();
      final controller = AppController(
        channelManager: ChannelManager(
          selectionStore: MemoryChannelSelectionStore(
            selectedChannelId: 'codex-developer',
          ),
        ),
        stateMachine: AiRemoteStateMachine(),
        voiceEngine: engine,
        translatorService: MockTranslatorService(latency: Duration.zero),
        audioCapture: audio,
        speechOutput: RecordingSpeechOutput(),
        codexChannelIds: const {'codex-developer'},
      );
      await controller.initialize();

      await controller.handleRemoteCommand(RemoteCommand.play);

      expect(audio.startCount, 0);
      expect(controller.state, AiRemoteState.error);
      expect(controller.errorMessage, contains('autorizza'));

      await controller.cancelCurrentInteraction();
      controller.authorizeNextCodexTurn();
      await controller.handleRemoteCommand(RemoteCommand.play);
      expect(controller.state, AiRemoteState.listening);
      await controller.handleRemoteCommand(RemoteCommand.play);
      expect(controller.state, AiRemoteState.listening);
      expect(audio.startCount, 1);
      await controller.handleRemoteCommand(RemoteCommand.stop);
      expect(
        engine.voiceRequests.single.backendTarget,
        VoiceBackendTarget.codex,
      );
      expect(controller.codexTurnConsentActive, isFalse);
    },
  );

  test(
    'mock push-to-talk produces speech and preserves channel context',
    () async {
      final audio = FakeAudioCaptureService();
      final speech = RecordingSpeechOutput();
      final controller = AppController(
        channelManager: ChannelManager(
          selectionStore: MemoryChannelSelectionStore(),
        ),
        stateMachine: AiRemoteStateMachine(),
        voiceEngine: MockVoiceEngine(latency: Duration.zero),
        translatorService: MockTranslatorService(latency: Duration.zero),
        audioCapture: audio,
        speechOutput: speech,
      );
      await controller.initialize();

      await controller.handleRemoteCommand(RemoteCommand.play);
      expect(controller.state, AiRemoteState.listening);
      await controller.handleRemoteCommand(RemoteCommand.stop);

      expect(controller.state, AiRemoteState.channelSelected);
      expect(controller.selectedSession.messages, hasLength(2));
      expect(speech.utterances, hasLength(1));

      await controller.handleRemoteCommand(RemoteCommand.next);
      expect(controller.selectedChannel.id, 'translator');
      expect(controller.selectedSession.messages, isEmpty);
      expect(
        controller.channelManager.sessionFor('general-chat').messages,
        hasLength(2),
      );
    },
  );

  test('translator reverses direction and speaks target language', () async {
    final speech = RecordingSpeechOutput();
    final controller = AppController(
      channelManager: ChannelManager(
        selectionStore: MemoryChannelSelectionStore(
          selectedChannelId: 'translator',
        ),
      ),
      stateMachine: AiRemoteStateMachine(),
      voiceEngine: MockVoiceEngine(latency: Duration.zero),
      translatorService: MockTranslatorService(latency: Duration.zero),
      audioCapture: FakeAudioCaptureService(),
      speechOutput: speech,
    );
    await controller.initialize();
    await controller.reverseTranslationDirection();

    await controller.startPushToTalk();
    await controller.finishPushToTalk();

    expect(controller.selectedSession.messages, hasLength(2));
    expect(speech.utterances.single.languageCode, 'it');
    expect(speech.utterances.single.text, 'Buongiorno, come stai?');
  });

  test('remote adapter receives channel state and controls the app', () async {
    final remote = FakeRemoteDisplayAdapter();
    final controller = AppController(
      channelManager: ChannelManager(
        selectionStore: MemoryChannelSelectionStore(),
      ),
      stateMachine: AiRemoteStateMachine(),
      voiceEngine: MockVoiceEngine(latency: Duration.zero),
      translatorService: MockTranslatorService(latency: Duration.zero),
      audioCapture: FakeAudioCaptureService(),
      speechOutput: RecordingSpeechOutput(),
      remoteAdapter: remote,
    );
    await controller.initialize();

    expect(controller.remoteConnectionState, RemoteConnectionState.connected);
    expect(remote.presentations.last.channelName, 'General Chat');

    remote.emit(RemoteCommand.next);
    await Future<void>.delayed(Duration.zero);
    expect(controller.selectedChannel.id, 'translator');
    expect(remote.presentations.last.channelName, 'Translator');

    remote.emit(RemoteCommand.play);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, AiRemoteState.listening);

    remote.emit(RemoteCommand.stop);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.state, AiRemoteState.channelSelected);
    expect(controller.selectedSession.messages, hasLength(2));

    await controller.shutdown();
  });

  test('live chord mode owns remote navigation and presentation', () async {
    final remote = FakeRemoteDisplayAdapter();
    final chordMonitor = ChordMonitorController(
      capture: FakeAudioPlaybackCapture(),
      analyzer: PcmChordAnalyzer(),
    );
    final controller = AppController(
      channelManager: ChannelManager(
        selectionStore: MemoryChannelSelectionStore(),
      ),
      stateMachine: AiRemoteStateMachine(),
      voiceEngine: MockVoiceEngine(latency: Duration.zero),
      translatorService: MockTranslatorService(latency: Duration.zero),
      audioCapture: FakeAudioCaptureService(),
      speechOutput: RecordingSpeechOutput(),
      remoteAdapter: remote,
      chordMonitor: chordMonitor,
    );
    await controller.initialize();
    await controller.startChordMonitor();

    expect(controller.isChordMonitorActive, isTrue);
    expect(remote.presentations.last.channelName, 'LIVE CHORD MONITOR');
    final selectedIndex = controller.channelManager.selectedIndex;

    await controller.handleRemoteCommand(RemoteCommand.previous);
    expect(controller.channelManager.selectedIndex, selectedIndex);
    expect(controller.chordMonitorSpeedLabel, 'AUTO');
    expect(remote.presentations.last.nowPlayingLabel, 'LIVE');

    await controller.handleRemoteCommand(RemoteCommand.next);
    expect(controller.channelManager.selectedIndex, selectedIndex);
    expect(controller.chordMonitorSpeedLabel, 'AUTO');
    expect(remote.presentations.last.nowPlayingLabel, 'LIVE');

    await controller.handleRemoteCommand(RemoteCommand.stop);
    expect(controller.isChordMonitorActive, isFalse);
    expect(remote.presentations.last.channelName, 'General Chat');
    await controller.shutdown();
  });
}
