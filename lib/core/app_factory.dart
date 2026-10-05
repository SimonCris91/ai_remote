import 'package:ai_remote/channels/channel_manager.dart';
import 'package:ai_remote/core/app_controller.dart';
import 'package:ai_remote/core/state/ai_remote_state_machine.dart';
import 'package:ai_remote/remote/media_session_remote_adapter.dart';
import 'package:ai_remote/remote/remote_controller.dart';
import 'package:ai_remote/services/channel_selection_store.dart';
import 'package:ai_remote/services/screen_awake_service.dart';
import 'package:ai_remote/services/watch_live_display_service.dart';
import 'package:ai_remote/music/chord_analyzer.dart';
import 'package:ai_remote/music/chord_monitor.dart';
import 'package:ai_remote/music/system_audio_capture.dart';
import 'package:ai_remote/music/pitch_tuner.dart';
import 'package:ai_remote/translator/mock_translator_service.dart';
import 'package:ai_remote/voice/audio_capture_service.dart';
import 'package:ai_remote/voice/mock_voice_engine.dart';
import 'package:ai_remote/voice/speech_output.dart';
import 'package:ai_remote/services/google_identity_service.dart';
import 'package:ai_remote/services/pairing_identity_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

Future<AppController> createDefaultAppController() async {
  const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  const backendUrl = String.fromEnvironment('AI_REMOTE_BACKEND_URL');
  const codexChannelConfig = String.fromEnvironment('AI_REMOTE_CODEX_CHANNELS');
  final codexChannelIds = codexChannelConfig
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
  final parsedBackendUri = Uri.tryParse(backendUrl);
  final voiceBackendUri =
      parsedBackendUri != null &&
          parsedBackendUri.scheme == 'https' &&
          parsedBackendUri.hasAuthority &&
          parsedBackendUri.host.isNotEmpty
      ? parsedBackendUri
      : null;
  final googleIdentityService =
      googleServerClientId.isNotEmpty && voiceBackendUri != null
      ? GoogleIdentityService(serverClientId: googleServerClientId)
      : null;
  final pairingIdentityService =
      voiceBackendUri != null && googleServerClientId.isEmpty
      ? PairingIdentityService(backendUri: voiceBackendUri)
      : null;
  RemoteAdapter? remoteAdapter;
  final mediaSessionAdapter = MediaSessionRemoteAdapter();
  try {
    await AudioService.init(
      builder: () => mediaSessionAdapter,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.airemote.ai_remote.remote',
        androidNotificationChannelName: 'AI Remote controller',
        androidNotificationChannelDescription:
            'Mantiene attivi i comandi di orologio, cuffie e auto.',
        androidStopForegroundOnPause: false,
      ),
    );
    // AI Remote speaks through TTS instead of a conventional music player.
    // Android does not automatically route media-button events to TTS-only
    // sessions, so explicitly opt this session in.  Without this call the
    // Bip U Pro can display the channel metadata and adjust volume, but
    // Play/Pause/Previous/Next never reach the RemoteAdapter.
    await AudioService.androidForceEnableMediaButtons();
    final audioSession = await AudioSession.instance;
    await audioSession.configure(const AudioSessionConfiguration.speech());
    remoteAdapter = mediaSessionAdapter;
  } catch (error, stackTrace) {
    await mediaSessionAdapter.dispose();
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'ai_remote',
        context: ErrorDescription('initializing the media remote adapter'),
      ),
    );
  }

  return AppController(
    channelManager: ChannelManager(
      selectionStore: SharedPreferencesChannelSelectionStore(),
      catalogStore: SharedPreferencesChannelCatalogStore(),
    ),
    stateMachine: AiRemoteStateMachine(),
    voiceEngine: MockVoiceEngine(),
    googleIdentityService: voiceBackendUri == null
        ? null
        : googleIdentityService,
    pairingIdentityService: pairingIdentityService,
    voiceBackendUri: voiceBackendUri,
    codexChannelIds: codexChannelIds,
    translatorService: MockTranslatorService(),
    audioCapture: RecordAudioCaptureService(),
    speechOutput: FlutterTtsSpeechOutput(),
    remoteAdapter: remoteAdapter,
    chordMonitor: ChordMonitorController(
      capture: AndroidAudioPlaybackCapture(),
      analyzer: PcmChordAnalyzer(),
    ),
    pitchTuner: PitchTunerController(capture: MicrophonePitchCapture()),
    screenAwake: const ScreenAwakeService(),
    watchDisplay: const WatchLiveDisplayService(),
  );
}
