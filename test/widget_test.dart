import 'package:ai_remote/channels/channel_manager.dart';
import 'package:ai_remote/core/app_controller.dart';
import 'package:ai_remote/core/state/ai_remote_state_machine.dart';
import 'package:ai_remote/main.dart';
import 'package:ai_remote/music/chord_analyzer.dart';
import 'package:ai_remote/music/chord_monitor.dart';
import 'package:ai_remote/music/system_audio_capture.dart';
import 'package:ai_remote/services/channel_selection_store.dart';
import 'package:ai_remote/translator/mock_translator_service.dart';
import 'package:ai_remote/voice/mock_voice_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('Codex Developer shows explicit one-turn consent', (
    tester,
  ) async {
    final controller = AppController(
      channelManager: ChannelManager(
        selectionStore: MemoryChannelSelectionStore(
          selectedChannelId: 'codex-developer',
        ),
      ),
      stateMachine: AiRemoteStateMachine(),
      voiceEngine: FakeLiveVoiceEngine(),
      translatorService: MockTranslatorService(latency: Duration.zero),
      audioCapture: FakeAudioCaptureService(),
      speechOutput: RecordingSpeechOutput(),
      codexChannelIds: const {'codex-developer'},
    );
    await controller.initialize();
    await tester.pumpWidget(AiRemoteApp(controller: controller));

    expect(find.byKey(const Key('codexDeveloperCard')), findsOneWidget);
    expect(find.byKey(const Key('authorizeCodexTurn')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('authorizeCodexTurn')));
    await tester.tap(find.byKey(const Key('authorizeCodexTurn')));
    await tester.pumpAndSettle();
    expect(find.text('Autorizza un turno Codex'), findsOneWidget);

    await tester.tap(find.byKey(const Key('approveCodexTurn')));
    await tester.pumpAndSettle();
    expect(controller.codexTurnConsentActive, isTrue);
    expect(find.textContaining('Un turno autorizzato'), findsOneWidget);
    await controller.cancelCurrentInteraction();
  });

  testWidgets('phone UI navigates channels with remote controls', (
    tester,
  ) async {
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
    await tester.pumpWidget(AiRemoteApp(controller: controller));

    expect(find.text('GENERAL CHAT'), findsOneWidget);
    expect(find.text('MOCK'), findsOneWidget);
    expect(find.text('LIVE CHORD MONITOR'), findsNothing);
    expect(find.byKey(const Key('tunerButton')), findsNothing);
    expect(find.byKey(const Key('chordMonitorButton')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('nextButton')));
    await tester.tap(find.byKey(const Key('nextButton')));
    await tester.pumpAndSettle();

    expect(find.text('TRANSLATOR'), findsWidgets);
    expect(
      find.byKey(const Key('reverseTranslationDirection')),
      findsOneWidget,
    );
  });

  testWidgets('phone UI sends a typed message to the selected channel', (
    tester,
  ) async {
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
    await tester.pumpWidget(AiRemoteApp(controller: controller));
    await tester.ensureVisible(find.byKey(const Key('messageInput')));
    await tester.enterText(
      find.byKey(const Key('messageInput')),
      'Messaggio scritto',
    );
    await tester.tap(find.byKey(const Key('sendTextMessage')));
    await tester.pumpAndSettle();

    expect(
      controller.selectedSession.messages.first.content,
      'Messaggio scritto',
    );
    expect(
      controller.selectedSession.messages.last.content,
      contains('[MOCK]'),
    );
  });

  testWidgets(
    'active chord monitor replaces the agent screen and shows level',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = AppController(
        channelManager: ChannelManager(
          selectionStore: MemoryChannelSelectionStore(
            selectedChannelId: 'technical-agent',
          ),
        ),
        stateMachine: AiRemoteStateMachine(),
        voiceEngine: MockVoiceEngine(latency: Duration.zero),
        translatorService: MockTranslatorService(latency: Duration.zero),
        audioCapture: FakeAudioCaptureService(),
        speechOutput: RecordingSpeechOutput(),
        chordMonitor: ChordMonitorController(
          capture: FakeAudioPlaybackCapture(),
          analyzer: PcmChordAnalyzer(),
        ),
      );
      await controller.initialize();
      await controller.startChordMonitor();
      await tester.pumpWidget(AiRemoteApp(controller: controller));

      expect(find.text('LIVE CHORD MONITOR'), findsOneWidget);
      expect(find.text('TECHNICAL AGENT'), findsNothing);
      expect(find.text('MOCK'), findsNothing);
      expect(find.byKey(const Key('liveSpeedLevel')), findsNothing);
      expect(find.textContaining('Aggiornamento automatico'), findsOneWidget);
      expect(find.byKey(const Key('previousButton')), findsNothing);
      expect(find.byKey(const Key('nextButton')), findsNothing);
      expect(controller.selectedChannel.id, 'technical-agent');
    },
  );
}
