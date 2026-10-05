import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

abstract interface class AudioPlaybackCapture {
  Stream<Uint8List> get pcm16Stream;
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

/// Android AudioPlaybackCapture bridge. It captures the mixed playback from
/// another app after the user approves Android's system consent dialog.
class AndroidAudioPlaybackCapture implements AudioPlaybackCapture {
  AndroidAudioPlaybackCapture({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel('com.airemote/audio_playback'),
       _eventChannel =
           eventChannel ??
           const EventChannel('com.airemote/audio_playback/events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  Stream<Uint8List>? _pcm16Stream;

  @override
  Stream<Uint8List> get pcm16Stream =>
      _pcm16Stream ??= _eventChannel.receiveBroadcastStream().map((event) {
        if (event is Uint8List) {
          return event;
        }
        if (event is List<int>) {
          return Uint8List.fromList(event);
        }
        throw const FormatException('Pacchetto audio Android non valido.');
      });

  @override
  Future<void> start() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'La cattura dell’audio di altre app è disponibile solo su Android.',
      );
    }
    await _methodChannel.invokeMethod<void>('start');
  }

  @override
  Future<void> stop() => _methodChannel.invokeMethod<void>('stop');

  @override
  Future<void> dispose() async {
    await stop();
    _pcm16Stream = null;
  }
}

class FakeAudioPlaybackCapture implements AudioPlaybackCapture {
  final StreamController<Uint8List> _streamController =
      StreamController<Uint8List>.broadcast();
  bool _running = false;

  @override
  Stream<Uint8List> get pcm16Stream => _streamController.stream;

  bool get isRunning => _running;

  @override
  Future<void> start() async => _running = true;

  @override
  Future<void> stop() async => _running = false;

  void emit(Uint8List chunk) {
    if (_running && !_streamController.isClosed) {
      _streamController.add(chunk);
    }
  }

  @override
  Future<void> dispose() async {
    _running = false;
    await _streamController.close();
  }
}
