import 'package:ai_remote/core/models/remote_command.dart';
import 'package:ai_remote/core/state/ai_remote_state.dart';
import 'package:ai_remote/remote/media_session_remote_adapter.dart';
import 'package:ai_remote/remote/remote_controller.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('media session exposes channel metadata and generic commands', () async {
    final adapter = MediaSessionRemoteAdapter();
    final commands = <RemoteCommand>[];
    final subscription = adapter.commands.listen(commands.add);
    await adapter.connect();

    await adapter.updatePresentation(
      const RemotePresentation(
        channelId: 'technical-agent',
        channelName: 'Technical Agent',
        channelType: 'AGENT',
        appState: AiRemoteState.channelSelected,
        detail: 'CHANNEL SELECTED',
      ),
    );

    expect(adapter.mediaItem.value?.title, 'Technical Agent');
    expect(adapter.mediaItem.value?.artist, 'AI Remote • AGENT');
    expect(adapter.playbackState.value.playing, isFalse);

    await adapter.skipToPrevious();
    await adapter.play();
    await adapter.pause();
    await adapter.skipToNext();

    expect(commands, [
      RemoteCommand.previous,
      RemoteCommand.play,
      RemoteCommand.stop,
      RemoteCommand.next,
    ]);
    await subscription.cancel();
    await adapter.dispose();
  });

  test('listening presentation switches the media control to pause', () async {
    final adapter = MediaSessionRemoteAdapter();
    await adapter.connect();
    await adapter.updatePresentation(
      const RemotePresentation(
        channelId: 'translator',
        channelName: 'Translator',
        channelType: 'TRANSLATOR',
        appState: AiRemoteState.listening,
        detail: 'Italiano → English',
      ),
    );

    expect(adapter.playbackState.value.playing, isTrue);
    expect(adapter.playbackState.value.controls.length, 3);
    await adapter.dispose();
  });

  test('chord presentation takes priority in the media title', () async {
    final adapter = MediaSessionRemoteAdapter();
    await adapter.connect();
    await adapter.updatePresentation(
      const RemotePresentation(
        channelId: 'general-chat',
        channelName: 'General Chat',
        channelType: 'CHAT',
        appState: AiRemoteState.channelSelected,
        nowPlayingLabel: 'C#m',
      ),
    );

    expect(adapter.mediaItem.value?.title, 'C#m');
    expect(adapter.mediaItem.value?.displaySubtitle, 'General Chat');
    expect(adapter.playbackState.value.playing, isTrue);
    await adapter.dispose();
  });

  test(
    'live mode publishes chord and level and watch pause stops it',
    () async {
      final adapter = MediaSessionRemoteAdapter();
      final commands = <RemoteCommand>[];
      final subscription = adapter.commands.listen(commands.add);
      await adapter.connect();
      await adapter.updatePresentation(
        const RemotePresentation(
          channelId: 'live-chord-monitor',
          channelName: 'LIVE CHORD MONITOR',
          channelType: 'LIVE AUDIO',
          appState: AiRemoteState.channelSelected,
          detail: 'Velocità 7/10',
          nowPlayingLabel: 'C 7/10',
        ),
      );

      expect(adapter.mediaItem.value?.title, 'C 7/10');
      expect(adapter.mediaItem.value?.displaySubtitle, 'LIVE CHORD MONITOR');
      expect(adapter.playbackState.value.controls[1], MediaControl.pause);
      await adapter.click(MediaButton.media);
      expect(commands, [RemoteCommand.stop]);
      await subscription.cancel();
      await adapter.dispose();
    },
  );

  test(
    'media click follows the AI listening state, not startup priming',
    () async {
      final adapter = MediaSessionRemoteAdapter();
      final commands = <RemoteCommand>[];
      final subscription = adapter.commands.listen(commands.add);
      await adapter.connect();

      await adapter.updatePresentation(
        const RemotePresentation(
          channelId: 'general-chat',
          channelName: 'General Chat',
          channelType: 'CHAT',
          appState: AiRemoteState.channelSelected,
        ),
      );
      await adapter.click(MediaButton.media);
      expect(commands, [RemoteCommand.play]);

      await adapter.updatePresentation(
        const RemotePresentation(
          channelId: 'general-chat',
          channelName: 'General Chat',
          channelType: 'CHAT',
          appState: AiRemoteState.listening,
        ),
      );
      await adapter.click(MediaButton.media);
      expect(commands, [RemoteCommand.play, RemoteCommand.stop]);

      await subscription.cancel();
      await adapter.dispose();
    },
  );
}
