import 'dart:async';

import 'package:ai_remote/core/models/remote_command.dart';
import 'package:ai_remote/core/state/ai_remote_state.dart';
import 'package:ai_remote/remote/remote_controller.dart';
import 'package:audio_service/audio_service.dart';

/// Bridges Android media controls to generic AI Remote commands.
///
/// Amazfit, headsets, car controls and other compatible devices see each AI
/// channel as a media item, without leaking device-specific behavior into the
/// application core.
class MediaSessionRemoteAdapter extends BaseAudioHandler
    implements RemoteDisplayAdapter {
  final StreamController<RemoteCommand> _commands =
      StreamController<RemoteCommand>.broadcast(sync: true);
  RemotePresentation? _presentation;
  bool _connected = false;
  int _presentationRevision = 0;

  @override
  String get adapterId => 'android-media-session';

  @override
  Stream<RemoteCommand> get commands => _commands.stream;

  @override
  Future<void> connect() async {
    _connected = true;
    // Android only promotes the media session to an active foreground
    // session after it has observed a playing state.  The Bip U Pro can
    // still show metadata while that session is inactive, but its Music
    // controls will not deliver media-button events.  Prime the session
    // once, then return to the idle push-to-talk state.  The service is
    // configured to remain foreground while paused, so the watch can keep
    // sending commands when the phone screen is locked.
    _publishPlaybackState(forcePlaying: true);
    await Future<void>.delayed(Duration.zero);
    _publishPlaybackState();
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    playbackState.add(
      playbackState.value.copyWith(
        controls: const [],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
  }

  @override
  Future<void> updatePresentation(RemotePresentation presentation) async {
    _presentation = presentation;
    final revision = ++_presentationRevision;
    final title = presentation.nowPlayingLabel ?? presentation.channelName;
    final item = MediaItem(
      // A new media id makes Android/Zepp treat each channel update as a
      // new track instead of reusing cached metadata from the old channel.
      id: 'ai-remote:${presentation.channelId}:$revision',
      title: title,
      artist: 'AI Remote • ${presentation.channelType}',
      album: presentation.detail ?? presentation.appState.label,
      displayTitle: title,
      displaySubtitle: presentation.nowPlayingLabel == null
          ? presentation.detail ?? presentation.channelType
          : presentation.channelName,
      displayDescription: presentation.appState.label,
      extras: <String, dynamic>{
        'aiRemoteRevision': revision,
        'aiRemoteChannelId': presentation.channelId,
      },
    );
    // Some watch clients cache the active queue item and ignore an in-place
    // metadata mutation. Publish an explicit empty item first, then replace
    // it with the new revision so AVRCP/Zepp receives a real track change.
    mediaItem.add(null);
    queue.add(const <MediaItem>[]);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (revision != _presentationRevision) return;
    mediaItem.add(item);
    queue.add(<MediaItem>[item]);
    _publishPlaybackState();
  }

  void _publishPlaybackState({bool forcePlaying = false}) {
    final listening = _presentation?.isListening ?? false;
    // A detected chord is also a live media presentation.  Keeping the
    // session active makes Android/AVRCP (including simple watch music
    // clients) prefer AI Remote metadata over the source app's song title.
    final chordMonitorActive = _presentation?.nowPlayingLabel != null;
    playbackState.add(
      PlaybackState(
        controls: _connected
            ? [
                MediaControl.skipToPrevious,
                listening ? MediaControl.pause : MediaControl.play,
                MediaControl.skipToNext,
              ]
            : const [],
        androidCompactActionIndices: _connected ? const [0, 1, 2] : const [],
        processingState: _connected
            ? AudioProcessingState.ready
            : AudioProcessingState.idle,
        playing: forcePlaying || listening || chordMonitorActive,
        // Zepp refreshes the displayed track more reliably when the active
        // queue item changes along with the media metadata.
        queueIndex: _presentationRevision,
      ),
    );
  }

  void _emit(RemoteCommand command) {
    if (_connected && !_commands.isClosed) {
      _commands.add(command);
    }
  }

  @override
  Future<void> play() async {
    _emit(RemoteCommand.play);
    playbackState.add(playbackState.value.copyWith(playing: true));
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:
        // The startup activation briefly publishes playing=true so Android
        // enables media buttons.  Use the AI state rather than that
        // transient platform value to make the first watch tap deterministic.
        if (_presentation?.isListening == true) {
          await pause();
        } else {
          await play();
        }
      case MediaButton.next:
        await skipToNext();
      case MediaButton.previous:
        await skipToPrevious();
    }
  }

  @override
  Future<void> pause() async {
    _emit(RemoteCommand.stop);
    playbackState.add(playbackState.value.copyWith(playing: false));
  }

  @override
  Future<void> skipToPrevious() async => _emit(RemoteCommand.previous);

  @override
  Future<void> skipToNext() async => _emit(RemoteCommand.next);

  @override
  Future<void> stop() async {
    _emit(RemoteCommand.stop);
    playbackState.add(playbackState.value.copyWith(playing: false));
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _commands.close();
  }
}
