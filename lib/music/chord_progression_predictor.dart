import 'package:ai_remote/music/chord_estimate.dart';

/// Lightweight music-theory prior for smoothing live chord suggestions.
/// It deliberately returns a hint, never replacing the measured chord.
class ChordProgressionPredictor {
  final List<String> _history = <String>[];

  List<String> get history => List.unmodifiable(_history);

  String? get predictedNext {
    if (_history.isEmpty) return null;
    final current = _rootOf(_history.last);
    if (current == null) return null;
    // Common pop/rock transitions: I→V/vi/IV, V→vi/IV, vi→IV/ii,
    // IV→I/V. The root is transposed from the last confirmed chord.
    const offsets = <int>[7, 9, 5, 0];
    final offset = offsets[_history.length % offsets.length];
    return _name((current + offset) % 12);
  }

  void observe(ChordEstimate estimate) {
    final label = estimate.label;
    if (_history.isNotEmpty && _history.last == label) return;
    _history.add(label);
    if (_history.length > 12) _history.removeAt(0);
  }

  void reset() => _history.clear();

  int? _rootOf(String label) {
    if (label.isEmpty) return null;
    const names = <String>[
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
    for (var index = 0; index < names.length; index++) {
      if (label.startsWith(names[index])) return index;
    }
    return null;
  }

  String _name(int root) => const [
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
  ][root];
}
