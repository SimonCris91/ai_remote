import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

class AudioCaptureResult {
  AudioCaptureResult({
    required this.duration,
    required this.bytesCaptured,
    Uint8List? pcm16,
  }) : pcm16 = pcm16 ?? Uint8List(0);

  final Duration duration;
  final int bytesCaptured;
  final Uint8List pcm16;
}

abstract interface class AudioCaptureService {
  Future<void> start();
  Future<AudioCaptureResult> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class RecordAudioCaptureService implements AudioCaptureService {
  static const int _maxRecordingBytes = 6 * 1024 * 1024;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<List<int>>? _subscription;
  DateTime? _startedAt;
  int _bytesCaptured = 0;
  final List<int> _audioBytes = <int>[];
  Object? _streamError;

  @override
  Future<void> start() async {
    if (_startedAt != null) {
      return;
    }
    if (!await _recorder.hasPermission()) {
      throw Exception('Permesso microfono non concesso.');
    }

    _bytesCaptured = 0;
    _audioBytes.clear();
    _streamError = null;
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 24000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );
    _startedAt = DateTime.now();
    _subscription = stream.listen((chunk) {
      _bytesCaptured += chunk.length;
      if (_audioBytes.length + chunk.length > _maxRecordingBytes) {
        _streamError = Exception(
          'Registrazione troppo lunga (limite circa 2 minuti).',
        );
        return;
      }
      _audioBytes.addAll(chunk);
    }, onError: (Object error) => _streamError = error);
  }

  @override
  Future<AudioCaptureResult> stop() async {
    final startedAt = _startedAt;
    if (startedAt == null) {
      return AudioCaptureResult(duration: Duration.zero, bytesCaptured: 0);
    }
    await _recorder.stop();
    await _subscription?.cancel();
    _subscription = null;
    _startedAt = null;
    if (_streamError case final error?) {
      _streamError = null;
      _audioBytes.clear();
      throw Exception('Errore durante la registrazione: $error');
    }
    return AudioCaptureResult(
      duration: DateTime.now().difference(startedAt),
      bytesCaptured: _bytesCaptured,
      pcm16: Uint8List.fromList(_audioBytes),
    );
  }

  @override
  Future<void> cancel() async {
    if (_startedAt != null) {
      await _recorder.cancel();
    }
    await _subscription?.cancel();
    _subscription = null;
    _startedAt = null;
    _audioBytes.clear();
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}
