import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ai_remote/music/chord_estimate.dart';

abstract interface class ChordAnalyzer {
  ChordEstimate? addPcm16(Uint8List bytes, {required int sampleRate});

  void reset();
}

/// Optional timing controls for analyzers that can change their refresh rate.
/// The monitor keeps the base [ChordAnalyzer] contract, so a future native or
/// ML analyzer can omit this capability without breaking the phone flow.
abstract interface class AdjustableChordAnalyzer implements ChordAnalyzer {
  Duration get analysisInterval;

  set analysisInterval(Duration value);
}

/// Small, dependency-free baseline for a live chord monitor.
///
/// It builds a chroma vector from a short PCM window and compares it with
/// common triad, seventh and suspended templates. This is
/// intentionally a replaceable baseline:
/// a native Essentia or on-device ML implementation can implement the same
/// [ChordAnalyzer] contract later without changing the phone/watch flow.
class PcmChordAnalyzer implements AdjustableChordAnalyzer {
  PcmChordAnalyzer({
    this.analysisWindow = 8192,
    this.analysisInterval = const Duration(milliseconds: 280),
    this.minimumConfidence = 0.22,
    this.changeConfirmationCount = 3,
  });

  final int analysisWindow;
  @override
  Duration analysisInterval;
  final double minimumConfidence;
  final int changeConfirmationCount;
  final List<int> _samples = <int>[];
  List<double>? _smoothedChroma;
  Duration _received = Duration.zero;
  Duration _lastAnalysis = Duration.zero;
  String? _stableLabel;
  final List<String> _recentLabels = <String>[];

  static const List<String> _pitchNames = <String>[
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

  static const List<_ChordTemplate> _templates = <_ChordTemplate>[
    _ChordTemplate('', <int>[0, 4, 7], <double>[0.52, 0.27, 0.21]),
    _ChordTemplate('m', <int>[0, 3, 7], <double>[0.52, 0.27, 0.21]),
    _ChordTemplate(
      '7',
      <int>[0, 4, 7, 10],
      <double>[0.40, 0.23, 0.20, 0.17],
      complexityBonus: 0.02,
    ),
    _ChordTemplate(
      'm7',
      <int>[0, 3, 7, 10],
      <double>[0.40, 0.23, 0.20, 0.17],
      complexityBonus: 0.02,
    ),
    _ChordTemplate(
      'maj7',
      <int>[0, 4, 7, 11],
      <double>[0.40, 0.23, 0.20, 0.17],
      complexityBonus: 0.02,
    ),
    _ChordTemplate('sus2', <int>[0, 2, 7], <double>[0.50, 0.29, 0.21]),
    _ChordTemplate('sus4', <int>[0, 5, 7], <double>[0.50, 0.29, 0.21]),
  ];

  @override
  ChordEstimate? addPcm16(Uint8List bytes, {required int sampleRate}) {
    if (bytes.isEmpty || sampleRate <= 0) {
      return null;
    }
    final data = ByteData.sublistView(bytes);
    for (var offset = 0; offset + 1 < bytes.length; offset += 2) {
      _samples.add(data.getInt16(offset, Endian.little));
    }
    // Playback capture is long-lived. Keep only the samples needed for the
    // next overlapping analysis window, not the whole song in memory.
    if (_samples.length > analysisWindow * 2) {
      _samples.removeRange(0, _samples.length - analysisWindow * 2);
    }
    _received += Duration(
      microseconds: (bytes.length * 1000000 / (sampleRate * 2)).round(),
    );
    if (_received - _lastAnalysis < analysisInterval ||
        _samples.length < analysisWindow) {
      return null;
    }

    final window = _samples.sublist(_samples.length - analysisWindow);
    _lastAnalysis = _received;
    return _estimate(window, sampleRate);
  }

  @override
  void reset() {
    _samples.clear();
    _received = Duration.zero;
    _lastAnalysis = Duration.zero;
    _stableLabel = null;
    _recentLabels.clear();
    _smoothedChroma = null;
  }

  ChordEstimate? _estimate(List<int> samples, int sampleRate) {
    final chroma = List<double>.filled(12, 0);
    var totalEnergy = 0.0;
    final windowed = List<double>.generate(samples.length, (index) {
      final hann =
          0.5 - 0.5 * math.cos(2 * math.pi * index / (samples.length - 1));
      return samples[index] * hann / 32768.0;
    }, growable: false);
    // Analyze exact semitone frequencies. Rounding to the nearest FFT bin
    // previously blurred neighboring notes, particularly in low octaves.
    for (var midi = 36; midi <= 84; midi++) {
      final frequency = 440 * math.pow(2, (midi - 69) / 12).toDouble();
      final magnitude = math.sqrt(
        math.max(0, _goertzel(windowed, sampleRate, frequency)),
      );
      chroma[midi % 12] += magnitude;
      totalEnergy += magnitude;
    }
    if (totalEnergy <= 0.000001) {
      return null;
    }

    final normalized = chroma
        .map((value) => value / totalEnergy)
        .toList(growable: false);
    final previous = _smoothedChroma;
    final smoothed = previous == null
        ? normalized
        : List<double>.generate(
            12,
            (index) => previous[index] * 0.25 + normalized[index] * 0.75,
            growable: false,
          );
    _smoothedChroma = smoothed;
    var bestScore = -1.0;
    var bestLabel = '';
    for (var root = 0; root < 12; root++) {
      for (final template in _templates) {
        final score = _templateScore(smoothed, root, template);
        final label = '${_pitchNames[root]}${template.suffix}';
        if (score > bestScore) {
          bestScore = score;
          bestLabel = label;
        }
      }
    }

    if (bestScore < minimumConfidence || bestLabel.isEmpty) {
      return null;
    }
    if (_stableLabel == bestLabel) {
      // Keep the last visible value on the phone and watch. A repeated
      // estimate for the same chord does not need to refresh the session.
      _recentLabels.clear();
      return null;
    }

    // A single analysis window can contain a beat boundary, bass note or
    // vocal tone. Keep a short temporal vote instead of switching on every
    // instantaneous template winner. This mirrors the temporal smoothing
    // used by practical chord trackers and lets a real change through even
    // when overlapping windows are not identical.
    final requiredVotes = changeConfirmationCount.clamp(1, 10);
    _recentLabels.add(bestLabel);
    final maxHistory = math.max(requiredVotes * 2 - 1, 3);
    if (_recentLabels.length > maxHistory) {
      _recentLabels.removeAt(0);
    }
    final votes = _recentLabels.where((label) => label == bestLabel).length;
    if (_stableLabel != null && votes < requiredVotes) {
      return null;
    }

    _stableLabel = bestLabel;
    _recentLabels.clear();
    return ChordEstimate(
      label: bestLabel,
      confidence: bestScore.clamp(0.0, 1.0).toDouble(),
      position: _received,
    );
  }

  double _templateScore(
    List<double> chroma,
    int root,
    _ChordTemplate template,
  ) {
    var score = 0.0;
    for (var i = 0; i < 12; i++) {
      final distance = (i - root + 12) % 12;
      final intervalIndex = template.intervals.indexOf(distance);
      final weight = intervalIndex == -1
          ? -0.03
          : template.weights[intervalIndex];
      score += chroma[i] * weight;
    }
    // A seventh/suspended label is allowed only when its extra tone is really
    // present. Otherwise prefer the principal triad, which is much more stable
    // on mixed music containing vocals, bass and percussion.
    final extraTonePresent =
        template.intervals.length < 4 ||
        chroma[(root + template.intervals.last) % 12] >= 0.10;
    return score + (extraTonePresent ? template.complexityBonus : 0);
  }

  double _goertzel(List<double> samples, int sampleRate, double frequency) {
    final omega = 2 * math.pi * frequency / sampleRate;
    final coefficient = 2 * math.cos(omega);
    var previous = 0.0;
    var previous2 = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final current = samples[i] + coefficient * previous - previous2;
      previous2 = previous;
      previous = current;
    }
    return previous2 * previous2 +
        previous * previous -
        coefficient * previous * previous2;
  }
}

class _ChordTemplate {
  const _ChordTemplate(
    this.suffix,
    this.intervals,
    this.weights, {
    this.complexityBonus = 0,
  });

  final String suffix;
  final List<int> intervals;
  final List<double> weights;
  final double complexityBonus;
}
