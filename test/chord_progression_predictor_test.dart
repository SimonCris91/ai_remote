import 'package:ai_remote/music/chord_estimate.dart';
import 'package:ai_remote/music/chord_progression_predictor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('predictor keeps a short confirmed history and proposes a hint', () {
    final predictor = ChordProgressionPredictor();
    predictor.observe(
      const ChordEstimate(label: 'C', confidence: 0.8, position: Duration.zero),
    );
    expect(predictor.history, ['C']);
    expect(predictor.predictedNext, isNotNull);
    predictor.observe(
      const ChordEstimate(label: 'C', confidence: 0.8, position: Duration.zero),
    );
    expect(predictor.history, ['C']);
  });
}
