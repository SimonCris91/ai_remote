import 'package:ai_remote/core/models/remote_command.dart';

typedef RemoteAction = Future<void> Function();

class RemoteCommandHandler {
  const RemoteCommandHandler({
    required this.onPrevious,
    required this.onPlay,
    required this.onNext,
    required this.onStop,
  });

  final RemoteAction onPrevious;
  final RemoteAction onPlay;
  final RemoteAction onNext;
  final RemoteAction onStop;

  Future<void> handle(RemoteCommand command) => switch (command) {
    RemoteCommand.previous => onPrevious(),
    RemoteCommand.play => onPlay(),
    RemoteCommand.next => onNext(),
    RemoteCommand.stop => onStop(),
  };
}
