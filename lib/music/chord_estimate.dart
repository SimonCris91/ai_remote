class ChordEstimate {
  const ChordEstimate({
    required this.label,
    required this.confidence,
    required this.position,
  });

  final String label;
  final double confidence;
  final Duration position;

  String get displayConfidence => '${(confidence * 100).round()}%';

  @override
  bool operator ==(Object other) =>
      other is ChordEstimate &&
      label == other.label &&
      confidence == other.confidence &&
      position == other.position;

  @override
  int get hashCode => Object.hash(label, confidence, position);
}
