class TranslationDirection {
  const TranslationDirection({
    required this.sourceCode,
    required this.sourceName,
    required this.targetCode,
    required this.targetName,
  });

  final String sourceCode;
  final String sourceName;
  final String targetCode;
  final String targetName;

  TranslationDirection reversed() => TranslationDirection(
    sourceCode: targetCode,
    sourceName: targetName,
    targetCode: sourceCode,
    targetName: sourceName,
  );

  String get label => '$sourceName  →  $targetName';
}
