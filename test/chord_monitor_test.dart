import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ai_remote/music/chord_analyzer.dart';
import 'package:ai_remote/music/chord_monitor.dart';
import 'package:ai_remote/music/chord_timeline.dart';
import 'package:ai_remote/music/system_audio_capture.dart';
import 'package:ai_remote/music/track_recognition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PCM baseline recognizes a clean C major triad', () {
    final analyzer = PcmChordAnalyzer(
      analysisWindow: 4096,
      analysisInterval: Duration.zero,
      minimumConfidence: 0.05,
    );
    final bytes = _triadBytes(const [
      261.63,
      329.63,
      392.00,
    ], sampleCount: 4096);

    final estimate = analyzer.addPcm16(bytes, sampleRate: 24000);

    expect(estimate, isNotNull);
    expect(estimate!.label, 'C');
    expect(estimate.confidence, inInclusiveRange(0.22, 1.0));
  });

  test('PCM baseline recognizes a dominant seventh chord', () {
    final analyzer = PcmChordAnalyzer(
      analysisWindow: 4096,
      analysisInterval: Duration.zero,
      minimumConfidence: 0.05,
    );
    final bytes = _triadBytes(const [
      261.63,
      329.63,
      392.00,
      466.16,
    ], sampleCount: 4096);

    final estimate = analyzer.addPcm16(bytes, sampleRate: 24000);

    expect(estimate, isNotNull);
    expect(estimate!.label, 'C7');
  });

  test('chord changes require two consecutive candidate windows', () {
    final analyzer = PcmChordAnalyzer(
      analysisWindow: 4096,
      analysisInterval: Duration.zero,
      minimumConfidence: 0.05,
      changeConfirmationCount: 2,
    );
    final cMajor = _triadBytes(const [
      261.63,
      329.63,
      392.00,
    ], sampleCount: 4096);
    final dMajor = _triadBytes(const [
      293.66,
      369.99,
      440.00,
    ], sampleCount: 4096);

    expect(analyzer.addPcm16(cMajor, sampleRate: 24000)?.label, 'C');
    expect(analyzer.addPcm16(dMajor, sampleRate: 24000), isNull);
    expect(analyzer.addPcm16(dMajor, sampleRate: 24000)?.label, 'D');
  });

  test('default analyzer confirms a chord change across multiple windows', () {
    final analyzer = PcmChordAnalyzer(analysisInterval: Duration.zero);
    final cMajor = _triadBytes(const [
      261.63,
      329.63,
      392.00,
    ], sampleCount: 8192);
    final dMajor = _triadBytes(const [
      293.66,
      369.99,
      440.00,
    ], sampleCount: 8192);

    expect(analyzer.addPcm16(cMajor, sampleRate: 24000)?.label, 'C');
    expect(analyzer.addPcm16(dMajor, sampleRate: 24000), isNull);
    expect(analyzer.addPcm16(dMajor, sampleRate: 24000), isNull);
    expect(analyzer.addPcm16(dMajor, sampleRate: 24000)?.label, 'D');
  });

  test('tuned analysis distinguishes common major and minor chords', () {
    final cases = <(String, List<double>)>[
      ('G', const [196.00, 246.94, 293.66]),
      ('Am', const [220.00, 261.63, 329.63]),
      ('F', const [174.61, 220.00, 261.63]),
    ];
    for (final (label, frequencies) in cases) {
      final analyzer = PcmChordAnalyzer(analysisInterval: Duration.zero);
      final estimate = analyzer.addPcm16(
        _triadBytes(frequencies, sampleCount: 8192),
        sampleRate: 24000,
      );
      expect(estimate?.label, label, reason: 'Accordo atteso: $label');
    }
  });

  test('chord monitor forwards capture chunks to the analyzer', () async {
    final capture = FakeAudioPlaybackCapture();
    final monitor = ChordMonitorController(
      capture: capture,
      analyzer: PcmChordAnalyzer(
        analysisWindow: 4096,
        analysisInterval: Duration.zero,
        minimumConfidence: 0.05,
      ),
    );

    await monitor.start();
    capture.emit(
      _triadBytes(const [261.63, 329.63, 392.00], sampleCount: 4096),
    );

    await Future<void>.delayed(Duration.zero);
    expect(monitor.isRunning, isTrue);
    expect(monitor.current?.label, 'C');
    await monitor.stop();
    expect(monitor.isRunning, isFalse);
    monitor.dispose();
  });

  test(
    'catalog timeline overrides local estimate after a track match',
    () async {
      final capture = FakeAudioPlaybackCapture();
      final monitor = ChordMonitorController(
        capture: capture,
        analyzer: PcmChordAnalyzer(
          analysisWindow: 4096,
          analysisInterval: Duration.zero,
          minimumConfidence: 0.05,
        ),
        trackRecognition: MockTrackRecognitionService(matchAfterChunks: 1),
        chordTimelineService: MockChordTimelineService(
          timelines: {
            'mock-recording': ChordTimeline(
              recordingId: 'mock-recording',
              entries: const [
                ChordTimelineEntry(start: Duration.zero, label: 'G'),
              ],
            ),
          },
        ),
      );

      await monitor.start();
      capture.emit(
        _triadBytes(const [261.63, 329.63, 392.00], sampleCount: 4096),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(monitor.recognizedTrack?.title, 'Demo Song');
      expect(monitor.chordTimeline?.at(Duration.zero)?.label, 'G');
      expect(monitor.current?.label, 'G');
      await monitor.stop();
      monitor.dispose();
    },
  );

  test('chord monitor keeps a fixed human-readable refresh cadence', () {
    final analyzer = PcmChordAnalyzer();
    final monitor = ChordMonitorController(
      capture: FakeAudioPlaybackCapture(),
      analyzer: analyzer,
    );

    expect(monitor.speedLabel, 'AUTO');
    expect(monitor.refreshInterval, const Duration(milliseconds: 280));
    expect(analyzer.analysisInterval, const Duration(milliseconds: 280));
    monitor.slower();
    expect(monitor.speedLabel, 'AUTO');
    expect(analyzer.analysisInterval, const Duration(milliseconds: 280));
    monitor.faster();
    expect(monitor.speedLabel, 'AUTO');
    expect(analyzer.analysisInterval, const Duration(milliseconds: 280));
    monitor.dispose();
  });
}

Uint8List _triadBytes(List<double> frequencies, {required int sampleCount}) {
  final data = ByteData(sampleCount * 2);
  for (var i = 0; i < sampleCount; i++) {
    final value = frequencies
        .map(
          (frequency) => math.sin(2 * math.pi * frequency * i / 24000) * 6500,
        )
        .reduce((left, right) => left + right)
        .round()
        .clamp(-32768, 32767);
    data.setInt16(i * 2, value, Endian.little);
  }
  return data.buffer.asUint8List();
}
