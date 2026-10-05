import 'package:ai_remote/core/models/remote_command.dart';
import 'package:ai_remote/core/state/ai_remote_state.dart';

enum RemoteConnectionState { unavailable, connecting, connected, error }

class RemotePresentation {
  const RemotePresentation({
    required this.channelId,
    required this.channelName,
    required this.channelType,
    required this.appState,
    this.detail,
    this.nowPlayingLabel,
  });

  final String channelId;
  final String channelName;
  final String channelType;
  final AiRemoteState appState;
  final String? detail;

  /// Optional high-priority value for simple media displays, such as the
  /// current chord detected from an external music app.
  final String? nowPlayingLabel;

  bool get isListening =>
      appState == AiRemoteState.listening ||
      channelId == 'live-chord-monitor' ||
      channelId == 'tuner';

  @override
  bool operator ==(Object other) =>
      other is RemotePresentation &&
      channelId == other.channelId &&
      channelName == other.channelName &&
      channelType == other.channelType &&
      appState == other.appState &&
      detail == other.detail &&
      nowPlayingLabel == other.nowPlayingLabel;

  @override
  int get hashCode => Object.hash(
    channelId,
    channelName,
    channelType,
    appState,
    detail,
    nowPlayingLabel,
  );
}

abstract interface class RemoteController {
  Stream<RemoteCommand> get commands;
  Future<void> connect();
  Future<void> disconnect();
  Future<void> dispose();
}

/// Contract implemented later by Wear OS, Bluetooth buttons, headsets or cars.
/// Hardware adapters emit only generic [RemoteCommand] values.
abstract interface class RemoteAdapter implements RemoteController {
  String get adapterId;
}

abstract interface class RemoteDisplayAdapter implements RemoteAdapter {
  Future<void> updatePresentation(RemotePresentation presentation);
}
