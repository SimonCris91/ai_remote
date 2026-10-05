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

    await tester.tap(find.byKey(const Key('nextButton')));
    await tester.pumpAndSettle();

    expect(find.text('TRANSLATOR'), findsWidgets);
    expect(
      find.byKey(const Key('reverseTranslationDirection')),
      findsOneWidget,
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
