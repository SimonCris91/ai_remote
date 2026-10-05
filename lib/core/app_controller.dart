import 'dart:async';

import 'package:ai_remote/channels/channel_manager.dart';
import 'package:ai_remote/core/models/channel.dart';
import 'package:ai_remote/core/models/channel_type.dart';
import 'package:ai_remote/core/models/conversation_message.dart';
import 'package:ai_remote/core/models/conversation_session.dart';
import 'package:ai_remote/core/models/remote_command.dart';
import 'package:ai_remote/core/models/translation_direction.dart';
import 'package:ai_remote/core/models/voice_session.dart';
import 'package:ai_remote/core/state/ai_remote_state.dart';
import 'package:ai_remote/core/state/ai_remote_state_machine.dart';
import 'package:ai_remote/music/chord_monitor.dart';
import 'package:ai_remote/music/pitch_tuner.dart';
import 'package:ai_remote/remote/remote_command_handler.dart';
import 'package:ai_remote/remote/remote_controller.dart';
import 'package:ai_remote/services/screen_awake_service.dart';
import 'package:ai_remote/services/watch_live_display_service.dart';
import 'package:ai_remote/services/ai_identity_service.dart';
import 'package:ai_remote/services/pairing_identity_service.dart';
import 'package:ai_remote/translator/translator_service.dart';
import 'package:ai_remote/voice/audio_capture_service.dart';
import 'package:ai_remote/voice/speech_output.dart';
import 'package:ai_remote/voice/voice_engine.dart';
import 'package:ai_remote/voice/openai_push_to_talk_voice_engine.dart';
import 'package:ai_remote/voice/mock_voice_engine.dart';
import 'package:flutter/foundation.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.channelManager,
    required this.stateMachine,
    required VoiceEngine voiceEngine,
    required this.translatorService,
    required this.audioCapture,
    required this.speechOutput,
    this.googleIdentityService,
    this.pairingIdentityService,
    this.voiceBackendUri,
    this.codexChannelIds = const <String>{},
    this.remoteAdapter,
    this.chordMonitor,
    this.pitchTuner,
    this.screenAwake = const NoopScreenAwakeService(),
    this.watchDisplay = const NoopWatchLiveDisplayService(),
  }) {
    _voiceEngine = voiceEngine;
    channelManager.addListener(_relayChanges);
    stateMachine.addListener(_relayChanges);
    chordMonitor?.addListener(_relayChanges);
    pitchTuner?.addListener(_relayChanges);
    remoteCommands = RemoteCommandHandler(
      onPrevious: _handleRemotePrevious,
      onPlay: _handleRemotePlay,
      onNext: _handleRemoteNext,
      onStop: _handleRemoteStop,
    );
  }

  final ChannelManager channelManager;
  final AiRemoteStateMachine stateMachine;
  late VoiceEngine _voiceEngine;
  VoiceEngine get voiceEngine => _voiceEngine;
  final AiIdentityService? googleIdentityService;
  final PairingIdentityService? pairingIdentityService;
  final Uri? voiceBackendUri;
  final Set<String> codexChannelIds;
  final TranslatorService translatorService;
  final AudioCaptureService audioCapture;
  final SpeechOutput speechOutput;
  final RemoteAdapter? remoteAdapter;
  final ChordMonitorController? chordMonitor;
  final PitchTunerController? pitchTuner;
  final ScreenAwakeService screenAwake;
  final WatchLiveDisplayService watchDisplay;
  late final RemoteCommandHandler remoteCommands;

  TranslationDirection _translationDirection = const TranslationDirection(
    sourceCode: 'it',
    sourceName: 'Italiano',
    targetCode: 'en',
    targetName: 'English',
  );
  VoiceSession? _voiceSession;
  String? _activeChannelId;
  int _operationId = 0;
  StreamSubscription<RemoteCommand>? _remoteSubscription;
  Future<void> _remoteCommandQueue = Future<void>.value();
  RemoteConnectionState _remoteConnectionState =
      RemoteConnectionState.unavailable;
  RemotePresentation? _lastRemotePresentation;

  AiRemoteState get state => stateMachine.state;
  String? get errorMessage => stateMachine.errorMessage;
  Channel get selectedChannel => channelManager.selectedChannel;
  ConversationSession get selectedSession => channelManager.selectedSession;
  TranslationDirection get translationDirection => _translationDirection;
  VoiceSession? get voiceSession => _voiceSession;
  bool get isMockMode => voiceEngine is MockVoiceEngine;
  bool get googleSignInAvailable =>
      googleIdentityService != null && voiceBackendUri != null;
  bool get pairingAvailable =>
      pairingIdentityService != null && voiceBackendUri != null;
  bool get isGoogleSignedIn =>
      voiceEngine is OpenAiPushToTalkVoiceEngine &&
      (googleIdentityService?.isSignedIn ?? false);
  String? get googleDisplayName => googleIdentityService?.displayName;
  bool get isPairingSignedIn =>
      voiceEngine is OpenAiPushToTalkVoiceEngine &&
      (pairingIdentityService?.isSignedIn ?? false);
  RemoteConnectionState get remoteConnectionState => _remoteConnectionState;
  String? get remoteAdapterName => remoteAdapter?.adapterId;
  String? get currentChord => chordMonitor?.current?.label;
  bool get isChordMonitorActive => chordMonitor?.isRunning ?? false;
  String get chordMonitorSpeedLabel => chordMonitor?.speedLabel ?? '—';
  String get chordMonitorTimingLabel =>
      chordMonitor?.speedDescription ?? 'Aggiornamento automatico';
  double? get chordMonitorBpm => chordMonitor?.bpm;
  String? get predictedNextChord => chordMonitor?.predictedNextChord;
  bool get isTunerActive => pitchTuner?.isRunning ?? false;
  PitchEstimate? get currentPitch => pitchTuner?.current;

  bool get selectedChannelIsActive => _activeChannelId == selectedChannel.id;

  Future<void> initialize() async {
    await channelManager.initialize();
    stateMachine.transitionTo(AiRemoteState.channelSelected);
    final pairing = pairingIdentityService;
    final backendUri = voiceBackendUri;
    if (pairing != null && backendUri != null) {
      final token = await pairing.currentAccessToken;
      if (token != null && token.isNotEmpty && voiceEngine is MockVoiceEngine) {
        await voiceEngine.dispose();
        _voiceEngine = OpenAiPushToTalkVoiceEngine(
          backendUri: backendUri,
          accessTokenProvider: () => pairing.currentAccessToken,
        );
      }
    }
    await _connectRemote();
  }

  Future<void> signInWithGoogle() async {
    final identity = googleIdentityService;
    final backendUri = voiceBackendUri;
    if (identity == null || backendUri == null) {
      throw StateError('Configurazione Google/backend non disponibile.');
    }
    await identity.signIn();
    final previousEngine = voiceEngine;
    _voiceEngine = OpenAiPushToTalkVoiceEngine(
      backendUri: backendUri,
      accessTokenProvider: () => identity.currentIdToken,
    );
    await previousEngine.dispose();
    _publishChanges();
  }

  Future<void> signOutGoogle() async {
    final identity = googleIdentityService;
    if (identity == null) return;
    await cancelCurrentInteraction();
    await voiceEngine.dispose();
    await identity.signOut();
    _voiceEngine = MockVoiceEngine();
    _publishChanges();
  }

  Future<void> pairWithBackend(String pairingCode) async {
    final identity = pairingIdentityService;
    final backendUri = voiceBackendUri;
    if (identity == null || backendUri == null) {
      throw StateError('Configurazione backend personale non disponibile.');
    }
    await identity.pair(pairingCode);
    final previousEngine = voiceEngine;
    _voiceEngine = OpenAiPushToTalkVoiceEngine(
      backendUri: backendUri,
      accessTokenProvider: () => identity.currentAccessToken,
    );
    await previousEngine.dispose();
    _publishChanges();
  }

  Future<void> signOutPairing() async {
    final identity = pairingIdentityService;
    if (identity == null) return;
    await cancelCurrentInteraction();
    await voiceEngine.dispose();
    await identity.signOut();
    _voiceEngine = MockVoiceEngine();
    _publishChanges();
  }

  Future<void> activateSelected() async {
    if (_isBusy) {
      return;
    }
    if (state == AiRemoteState.error || state == AiRemoteState.idle) {
      stateMachine.transitionTo(AiRemoteState.channelSelected);
    }
    _activeChannelId = selectedChannel.id;
    channelManager.activate();
    _publishChanges();
  }

  Future<void> previousChannel() async {
    await _prepareForChannelChange();
    await channelManager.previous();
  }

  Future<void> nextChannel() async {
    await _prepareForChannelChange();
    await channelManager.next();
  }

  Future<void> _handleRemotePrevious() async {
    if (isTunerActive) return;
    if (isChordMonitorActive) {
      // Navigation buttons do not control the analysis cadence. The monitor
      // keeps one stable refresh rate and the tempo tracker handles rhythm.
      return;
    }
    await previousChannel();
  }

  Future<void> _handleRemoteNext() async {
    if (isTunerActive) return;
    if (isChordMonitorActive) {
      // Keep ⏮/⏭ free from speed changes while chord monitoring is active.
      return;
    }
    await nextChannel();
  }

  Future<void> _handleRemotePlay() async {
    if (isTunerActive) {
      await stopTuner();
      return;
    }
    if (isChordMonitorActive) {
      await stopChordMonitor();
      return;
    }
    await startPushToTalk();
  }

  Future<void> _prepareForChannelChange() async {
    await cancelCurrentInteraction();
    _activeChannelId = null;
    if (state == AiRemoteState.error || state == AiRemoteState.idle) {
      stateMachine.transitionTo(AiRemoteState.channelSelected);
    }
    _publishChanges();
  }

  Future<void> startPushToTalk() async {
    if (state == AiRemoteState.listening ||
        state == AiRemoteState.processing ||
        state == AiRemoteState.translating) {
      return;
    }
    if (state == AiRemoteState.aiSpeaking) {
      await cancelCurrentInteraction();
    }
    if (state == AiRemoteState.error || state == AiRemoteState.idle) {
      stateMachine.transitionTo(AiRemoteState.channelSelected);
    }

    final operation = ++_operationId;
    _activeChannelId = selectedChannel.id;
    _voiceSession = VoiceSession(
      channelId: selectedChannel.id,
      mode: VoiceInteractionMode.pushToTalk,
    );
    _publishChanges();
    try {
      await audioCapture.start();
      if (operation != _operationId) {
        await audioCapture.cancel();
        return;
      }
      stateMachine.transitionTo(AiRemoteState.listening);
    } catch (error) {
      _voiceSession = null;
      stateMachine.fail(error);
    }
  }

  Future<void> finishPushToTalk() async {
    if (state != AiRemoteState.listening) {
      return;
    }
    final operation = _operationId;
    final channel = selectedChannel;
    final channelId = channel.id;
    try {
      stateMachine.transitionTo(AiRemoteState.processing);
      final audio = await audioCapture.stop();
      if (operation != _operationId) {
        return;
      }
      if (channel.type == ChannelType.translator) {
        await _runTranslation(operation, channelId, audio);
      } else {
        await _runVoiceTurn(operation, channel, audio);
      }
    } catch (error) {
      if (operation == _operationId) {
        _voiceSession = null;
        stateMachine.fail(error);
      }
    }
  }

  Future<void> _runVoiceTurn(
    int operation,
    Channel channel,
    AudioCaptureResult audio,
  ) async {
    final session = channelManager.sessionFor(channel.id);
    final result = await voiceEngine.processPushToTalkTurn(
      VoiceTurnRequest(
        channel: channel,
        history: session.messages,
        audio: audio,
        backendTarget: codexChannelIds.contains(channel.id)
            ? VoiceBackendTarget.codex
            : VoiceBackendTarget.openai,
      ),
    );
    if (operation != _operationId) {
      return;
    }
    channelManager
      ..addMessage(
        channel.id,
        ConversationMessage(
          role: ConversationRole.user,
          content: result.transcript,
        ),
      )
      ..addMessage(
        channel.id,
        ConversationMessage(
          role: ConversationRole.assistant,
          content: result.responseText,
        ),
      );
    stateMachine.transitionTo(AiRemoteState.aiSpeaking);
    await speechOutput.speak(result.responseText, languageCode: 'it');
    _completeOperation(operation);
  }

  Future<void> _runTranslation(
    int operation,
    String channelId,
    AudioCaptureResult audio,
  ) async {
    stateMachine.transitionTo(AiRemoteState.translating);
    final result = await translatorService.translateTurn(
      TranslationRequest(direction: _translationDirection, audio: audio),
    );
    if (operation != _operationId) {
      return;
    }
    channelManager
      ..addMessage(
        channelId,
        ConversationMessage(
          role: ConversationRole.user,
          content: result.sourceTranscript,
        ),
      )
      ..addMessage(
        channelId,
        ConversationMessage(
          role: ConversationRole.assistant,
          content: result.translatedText,
        ),
      );
    stateMachine.transitionTo(AiRemoteState.aiSpeaking);
    await speechOutput.speak(
      result.translatedText,
      languageCode: _translationDirection.targetCode,
    );
    _completeOperation(operation);
  }

  void _completeOperation(int operation) {
    if (operation != _operationId) {
      return;
    }
    _voiceSession = null;
    stateMachine.transitionTo(AiRemoteState.channelSelected);
  }

  Future<void> reverseTranslationDirection() async {
    if (selectedChannel.type != ChannelType.translator || _isBusy) {
      return;
    }
    _translationDirection = _translationDirection.reversed();
    _publishChanges();
  }

  Future<void> handleRemoteCommand(RemoteCommand command) =>
      remoteCommands.handle(command);

  Future<void> startChordMonitor() async {
    try {
      if (isTunerActive) await stopTuner();
      await chordMonitor?.start();
      await screenAwake.setEnabled(true);
      _publishChanges();
    } catch (error) {
      stateMachine.fail(error);
      _publishChanges(syncRemote: false);
    }
  }

  Future<void> stopChordMonitor() async {
    await chordMonitor?.stop();
    await screenAwake.setEnabled(false);
    _publishChanges();
  }

  Future<void> startTuner() async {
    try {
      if (isChordMonitorActive) await stopChordMonitor();
      await pitchTuner?.start();
      await screenAwake.setEnabled(true);
      _publishChanges();
    } catch (error) {
      stateMachine.fail(error);
      _publishChanges(syncRemote: false);
    }
  }

  Future<void> stopTuner() async {
    await pitchTuner?.stop();
    await screenAwake.setEnabled(false);
    _publishChanges();
  }

  Future<void> _handleRemoteStop() async {
    if (isTunerActive) {
      await stopTuner();
      return;
    }
    if (isChordMonitorActive) {
      await stopChordMonitor();
      return;
    }
    if (state == AiRemoteState.listening) {
      await finishPushToTalk();
      return;
    }
    await cancelCurrentInteraction();
  }

  Future<void> cancelCurrentInteraction() async {
    _operationId += 1;
    await Future.wait([
      audioCapture.cancel(),
      voiceEngine.cancel(),
      translatorService.cancel(),
      speechOutput.stop(),
    ]);
    _voiceSession = null;
    if (state != AiRemoteState.channelSelected &&
        state != AiRemoteState.idle &&
        state != AiRemoteState.disconnected) {
      stateMachine.transitionTo(AiRemoteState.channelSelected);
    }
  }

  bool get _isBusy => switch (state) {
    AiRemoteState.listening ||
    AiRemoteState.processing ||
    AiRemoteState.translating ||
    AiRemoteState.aiSpeaking => true,
    _ => false,
  };

  Future<void> _connectRemote() async {
    final adapter = remoteAdapter;
    if (adapter == null) {
      return;
    }
    _remoteConnectionState = RemoteConnectionState.connecting;
    _publishChanges(syncRemote: false);
    _remoteSubscription = adapter.commands.listen(
      _enqueueRemoteCommand,
      onError: (_) {
        _remoteConnectionState = RemoteConnectionState.error;
        _publishChanges(syncRemote: false);
      },
      onDone: () {
        _remoteConnectionState = RemoteConnectionState.unavailable;
        _publishChanges(syncRemote: false);
      },
    );
    try {
      await adapter.connect();
      _remoteConnectionState = RemoteConnectionState.connected;
      _publishChanges();
    } catch (_) {
      _remoteConnectionState = RemoteConnectionState.error;
      _publishChanges(syncRemote: false);
    }
  }

  void _enqueueRemoteCommand(RemoteCommand command) {
    _remoteCommandQueue = _remoteCommandQueue.then((_) async {
      try {
        await handleRemoteCommand(command);
      } catch (error) {
        stateMachine.fail(error);
      }
    });
  }

  void _syncRemotePresentation() {
    final adapter = remoteAdapter;
    if (adapter is! RemoteDisplayAdapter ||
        _remoteConnectionState != RemoteConnectionState.connected) {
      return;
    }
    final liveChordMode = isChordMonitorActive;
    final tunerMode = isTunerActive;
    final presentation = RemotePresentation(
      channelId: tunerMode
          ? 'tuner'
          : liveChordMode
          ? 'live-chord-monitor'
          : selectedChannel.id,
      channelName: tunerMode
          ? 'TUNER'
          : liveChordMode
          ? 'LIVE CHORD MONITOR'
          : selectedChannel.name,
      channelType: tunerMode
          ? 'PITCH'
          : liveChordMode
          ? 'LIVE AUDIO'
          : selectedChannel.type.label,
      appState: state,
      detail: tunerMode
          ? 'Microfono · ${currentPitch?.signedCents ?? 'in ascolto'}'
          : liveChordMode
          ? '${chordMonitor?.speedDescription ?? ''}${chordMonitorBpm == null ? '' : ' · Ritmo ${chordMonitorBpm!.round()} BPM'}${predictedNextChord == null ? '' : ' · Prossimo $predictedNextChord'}'
          : selectedChannel.type == ChannelType.translator
          ? _translationDirection.label
          : state.label,
      nowPlayingLabel: tunerMode
          ? '${currentPitch?.note ?? 'TUNER'} ${currentPitch?.signedCents ?? ''}'
          : liveChordMode
          ? '${currentChord ?? 'LIVE'}${chordMonitorBpm == null ? '' : ' · ${chordMonitorBpm!.round()} BPM'}'
          : null,
    );
    if (presentation == _lastRemotePresentation) {
      return;
    }
    _lastRemotePresentation = presentation;
    if (tunerMode || liveChordMode) {
      final liveValue = tunerMode
          ? '${currentPitch?.note ?? 'TUNER'} ${currentPitch?.signedCents ?? ''}'
          : '${currentChord ?? 'LIVE'}${chordMonitorBpm == null ? '' : ' · ${chordMonitorBpm!.round()} BPM'}';
      unawaited(
        watchDisplay.update(
          title: tunerMode ? 'ACCORDATORE' : 'LIVE CHORD MONITOR',
          subtitle: liveValue,
          content: liveValue,
        ),
      );
    } else {
      unawaited(watchDisplay.clear());
    }
    // Keep the phone-side channel change immediate. The media adapter tags
    // each presentation with a monotonic revision so Android/Zepp can
    // discard cached metadata without delaying command handling here.
    unawaited(_updateRemotePresentation(adapter, presentation));
  }

  Future<void> _updateRemotePresentation(
    RemoteDisplayAdapter adapter,
    RemotePresentation presentation,
  ) async {
    try {
      await adapter.updatePresentation(presentation);
    } catch (_) {
      _remoteConnectionState = RemoteConnectionState.error;
      _publishChanges(syncRemote: false);
    }
  }

  void _publishChanges({bool syncRemote = true}) {
    notifyListeners();
    if (syncRemote) {
      _syncRemotePresentation();
    }
  }

  void _relayChanges() => _publishChanges();

  Future<void> shutdown() async {
    await screenAwake.setEnabled(false);
    await watchDisplay.clear();
    await cancelCurrentInteraction();
    await _remoteSubscription?.cancel();
    if (remoteAdapter case final adapter?) {
      await adapter.disconnect();
      await adapter.dispose();
    }
    await audioCapture.dispose();
    await voiceEngine.dispose();
    await speechOutput.dispose();
    chordMonitor?.dispose();
    pitchTuner?.dispose();
    unawaited(watchDisplay.clear());
  }

  @override
  void dispose() {
    channelManager.removeListener(_relayChanges);
    stateMachine.removeListener(_relayChanges);
    chordMonitor?.removeListener(_relayChanges);
    pitchTuner?.removeListener(_relayChanges);
    super.dispose();
  }
}
