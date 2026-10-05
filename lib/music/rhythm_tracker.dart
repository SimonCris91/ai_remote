import 'dart:math' as math;
import 'dart:typed_data';

/// Lightweight onset/tempo tracker used to align chord changes with the beat.
/// It is intentionally conservative: when no stable beat is detected the
/// chord monitor falls back to its normal temporal confirmation.
class RhythmTracker {
  Duration _elapsed = Duration.zero;
  Duration? _lastOnset;
  double? _bpm;
  final List<double> _energyHistory = <double>[];
  final List<double> _tempoCandidates = <double>[];
  final List<double> _pendingTempo = <double>[];

  double? get bpm => _bpm;

  void reset() {
    _elapsed = Duration.zero;
    _lastOnset = null;
    _bpm = null;
    _energyHistory.clear();
    _tempoCandidates.clear();
    _pendingTempo.clear();
  }

  void addPcm16(Uint8List bytes, {required int sampleRate}) {
    if (bytes.isEmpty || sampleRate <= 0) return;
    final data = ByteData.sublistView(bytes);
    var sum = 0.0;
    var count = 0;
    for (var offset = 0; offset + 1 < bytes.length; offset += 2) {
      final sample = data.getInt16(offset, Endian.little) / 32768.0;
      sum += sample * sample;
      count++;
    }
    if (count == 0) return;
    final energy = math.sqrt(sum / count);
    final chunkDuration = Duration(
      microseconds: (bytes.length * 1000000 / (sampleRate * 2)).round(),
    );
    _elapsed += chunkDuration;
    _energyHistory.add(energy);
    if (_energyHistory.length > 18) _energyHistory.removeAt(0);
    if (_energyHistory.length < 5) return;

    final sorted = List<double>.from(_energyHistory)..sort();
    final baseline = sorted[sorted.length ~/ 2];
    final last = _lastOnset;
    final refractory =
        last == null || _elapsed - last > const Duration(milliseconds: 180);
    if (!refractory || energy < 0.008 || energy < baseline * 1.45) return;

    _lastOnset = _elapsed;
    if (last == null) return;
    final interval = _elapsed - last;
    if (interval < const Duration(milliseconds: 280) ||
        interval > const Duration(milliseconds: 1600)) {
      return;
    }
    final candidate = _normalizeTempo(60000 / interval.inMilliseconds);
    _updateTempo(candidate);
  }

  /// Keeps the estimate on a useful musical tempo grid. Onset detectors can
  /// lock to every second beat or to a subdivision, so octave-equivalent
  /// tempi are compared against the current stable estimate.
  double _normalizeTempo(double candidate) {
    var normalized = candidate;
    while (normalized < 60) {
      normalized *= 2;
    }
    while (normalized > 180) {
      normalized /= 2;
    }
    final stable = _bpm;
    if (stable == null) return normalized;
    final alternatives = <double>[
      normalized,
      normalized / 2,
      normalized * 2,
    ].where((value) => value >= 45 && value <= 210);
    return alternatives.reduce(
      (left, right) =>
          (left - stable).abs() <= (right - stable).abs() ? left : right,
    );
  }

  void _updateTempo(double candidate) {
    final stable = _bpm;
    if (stable == null) {
      _tempoCandidates.add(candidate);
      if (_tempoCandidates.length > 6) _tempoCandidates.removeAt(0);
      if (_tempoCandidates.length < 3) return;
      final median = _median(_tempoCandidates);
      final tolerance = math.max(4.0, median * 0.06);
      final supporters = _tempoCandidates
          .where((value) => (value - median).abs() <= tolerance)
          .length;
      // Do not publish a BPM based on one noisy interval. Three consistent
      // beat intervals are the minimum confidence for the display and gate.
      if (supporters >= 3) _bpm = median;
      return;
    }

    final tolerance = math.max(3.0, stable * 0.05);
    if ((candidate - stable).abs() <= tolerance) {
      // Small corrections are intentionally slow so the displayed tempo does
      // not jump every time a transient is detected.
      _bpm = stable * 0.92 + candidate * 0.08;
      _pendingTempo.clear();
      return;
    }

    _pendingTempo.add(candidate);
    if (_pendingTempo.length > 6) _pendingTempo.removeAt(0);
    if (_pendingTempo.length < 6) return;
    final pending = _median(_pendingTempo);
    final pendingTolerance = math.max(4.0, pending * 0.06);
    final supporters = _pendingTempo
        .where((value) => (value - pending).abs() <= pendingTolerance)
        .length;
    if (supporters < 5) return;

    // A real tempo change is possible, but it must be persistent and is
    // applied in small steps rather than jumping from (for example) 78 to
    // 118 BPM because of one missed or doubled onset.
    final step = (pending - stable).clamp(-2.0, 2.0);
    _bpm = stable + step;
    if ((_bpm! - pending).abs() <= tolerance) _pendingTempo.clear();
  }

  double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  /// Returns true when a pending chord is close enough to a detected beat.
  bool isNearBeat(Duration position) {
    final currentBpm = _bpm;
    final onset = _lastOnset;
    if (currentBpm == null || onset == null) return true;
    final beat = Duration(microseconds: (60000000 / currentBpm).round());
    if (beat.inMicroseconds <= 0) return true;
    final delta = position.inMicroseconds - onset.inMicroseconds;
    final phase = delta % beat.inMicroseconds;
    final distance = math.min(phase, beat.inMicroseconds - phase);
    return distance <= const Duration(milliseconds: 115).inMicroseconds;
  }
}
