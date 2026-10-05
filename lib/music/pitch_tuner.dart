import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

class PitchEstimate {
  const PitchEstimate({
    required this.note,
    required this.frequency,
    required this.cents,
  });

  final String note;
  final double frequency;
  final double cents;

  String get signedCents => '${cents >= 0 ? '+' : ''}${cents.round()}¢';
}

class MicrophonePitchCapture {
  MicrophonePitchCapture({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  StreamSubscription<List<int>>? _subscription;
  final StreamController<Uint8List> _chunks =
      StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get chunks => _chunks.stream;

  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw Exception('Permesso microfono non concesso.');
    }
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 24000,
        numChannels: 1,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );
    _subscription = stream.listen((chunk) {
      if (!_chunks.isClosed && chunk.isNotEmpty) {
        _chunks.add(Uint8List.fromList(chunk));
      }
    });
  }

  Future<void> stop() async {
    await _recorder.stop();
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
    await _chunks.close();
  }
}

class PitchTunerController extends ChangeNotifier {
  PitchTunerController({required this.capture, this.sampleRate = 24000});

  final MicrophonePitchCapture capture;
  final int sampleRate;
  StreamSubscription<Uint8List>? _subscription;
  PitchEstimate? _current;
  bool _running = false;
  bool _disposed = false;
  final List<int> _samples = <int>[];

  PitchEstimate? get current => _current;
  bool get isRunning => _running;

  Future<void> start() async {
    if (_running) return;
    _samples.clear();
    _current = null;
    _subscription = capture.chunks.listen(_onChunk);
    try {
      await capture.start();
      _running = true;
      notifyListeners();
    } catch (_) {
      await _subscription?.cancel();
      _subscription = null;
      rethrow;
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await capture.stop();
    _running = false;
    _current = null;
    if (!_disposed) notifyListeners();
  }

  void _onChunk(Uint8List bytes) {
    for (var offset = 0; offset + 1 < bytes.length; offset += 2) {
      var sample = bytes[offset] | (bytes[offset + 1] << 8);
      if (sample >= 0x8000) sample -= 0x10000;
      _samples.add(sample);
    }
    if (_samples.length > 4096) {
      _samples.removeRange(0, _samples.length - 4096);
    }
    if (_samples.length < 2048) return;
    final estimate = _estimate(_samples);
    if (estimate == null) return;
    // Hysteresis: hold a note until a new pitch is clearly present.
    if (_current != null &&
        (estimate.frequency - _current!.frequency).abs() < 2.5 &&
        estimate.cents.abs() < 48) {
      _current = PitchEstimate(
        note: _current!.note,
        frequency: estimate.frequency,
        cents: estimate.cents,
      );
    } else {
      _current = estimate;
    }
    notifyListeners();
  }

  PitchEstimate? _estimate(List<int> samples) {
    var energy = 0.0;
    for (final sample in samples) {
      energy += sample * sample;
    }
    if (energy < 1000000) return null;
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    var bestLag = 0;
    var bestCorrelation = 0.0;
    final minLag = (sampleRate / 1000).round();
    final maxLag = (sampleRate / 70).round();
    for (var lag = minLag; lag <= maxLag; lag++) {
      var correlation = 0.0;
      var normA = 0.0;
      var normB = 0.0;
      for (var i = 0; i < samples.length - lag; i += 2) {
        final a = samples[i] - mean;
        final b = samples[i + lag] - mean;
        correlation += a * b;
        normA += a * a;
        normB += b * b;
      }
      final normalized = correlation / math.sqrt((normA * normB) + 1e-9);
      if (normalized > bestCorrelation) {
        bestCorrelation = normalized;
        bestLag = lag;
      }
    }
    if (bestLag == 0 || bestCorrelation < 0.55) return null;
    final frequency = sampleRate / bestLag;
    final midi = 69 + 12 * (math.log(frequency / 440) / math.ln2);
    final nearest = midi.round();
    final cents = (midi - nearest) * 100;
    const notes = [
      'C',
      'C#',
      'D',
      'Eb',
      'E',
      'F',
      'F#',
      'G',
      'Ab',
      'A',
      'Bb',
      'B',
    ];
    return PitchEstimate(
      note: '${notes[nearest % 12]}${(nearest ~/ 12) - 1}',
      frequency: frequency,
      cents: cents,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    unawaited(capture.dispose());
    super.dispose();
  }
}
