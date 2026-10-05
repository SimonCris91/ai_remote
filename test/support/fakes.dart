import 'dart:async';

import 'package:ai_remote/core/models/remote_command.dart';
import 'package:ai_remote/remote/remote_controller.dart';
import 'package:ai_remote/voice/audio_capture_service.dart';
import 'package:ai_remote/voice/speech_output.dart';

class FakeAudioCaptureService implements AudioCaptureService {
  bool started = false;
  int startCount = 0;
  int stopCount = 0;

  @override
  Future<void> start() async {
    started = true;
    startCount += 1;
  }

  @override
  Future<AudioCaptureResult> stop() async {
    started = false;
    stopCount += 1;
    return AudioCaptureResult(
      duration: Duration(seconds: 1),
      bytesCaptured: 48000,
    );
  }

  @override
  Future<void> cancel() async => started = false;

  @override
  Future<void> dispose() async {}
}

class RecordingSpeechOutput implements SpeechOutput {
  final List<({String text, String languageCode})> utterances = [];

  @override
  Future<void> speak(String text, {required String languageCode}) async {
    utterances.add((text: text, languageCode: languageCode));
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class FakeRemoteDisplayAdapter implements RemoteDisplayAdapter {
  final StreamController<RemoteCommand> _commands =
      StreamController<RemoteCommand>.broadcast(sync: true);
  final List<RemotePresentation> presentations = [];
  bool connected = false;

  @override
  String get adapterId => 'fake-media-session';

  @override
  Stream<RemoteCommand> get commands => _commands.stream;

  @override
  Future<void> connect() async => connected = true;

  @override
  Future<void> disconnect() async => connected = false;

  @override
  Future<void> updatePresentation(RemotePresentation presentation) async {
    presentations.add(presentation);
  }

  void emit(RemoteCommand command) => _commands.add(command);

  @override
  Future<void> dispose() async => _commands.close();
}
