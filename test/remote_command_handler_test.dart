import 'package:ai_remote/core/models/remote_command.dart';
import 'package:ai_remote/remote/remote_command_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routes every hardware-independent command', () async {
    final calls = <String>[];
    final handler = RemoteCommandHandler(
      onPrevious: () async => calls.add('previous'),
      onPlay: () async => calls.add('play'),
      onNext: () async => calls.add('next'),
      onStop: () async => calls.add('stop'),
    );

    for (final command in RemoteCommand.values) {
      await handler.handle(command);
    }

    expect(calls, ['previous', 'play', 'next', 'stop']);
  });
}
