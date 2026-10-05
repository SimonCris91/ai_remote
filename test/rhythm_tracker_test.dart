import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ai_remote/music/rhythm_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('estimates a steady beat and exposes beat proximity', () {
    final tracker = RhythmTracker();

    // 100 ms frames at 24 kHz: four onset pulses spaced by 500 ms.
    for (var frame = 0; frame < 22; frame++) {
      final pulse = frame == 5 || frame == 10 || frame == 15 || frame == 20;
      tracker.addPcm16(_frame(pulse), sampleRate: 24000);
    }

    expect(tracker.bpm, closeTo(120, 1));
    expect(tracker.isNearBeat(const Duration(milliseconds: 2100)), isTrue);
    expect(tracker.isNearBeat(const Duration(milliseconds: 2350)), isFalse);
  });
}

Uint8List _frame(bool pulse) {
  const sampleRate = 24000;
  const frameSamples = 2400;
  final bytes = Uint8List(frameSamples * 2);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < frameSamples; index++) {
    final value = pulse
        ? (math.sin(2 * math.pi * 440 * index / sampleRate) * 0.35 * 32767)
              .round()
        : 0;
    data.setInt16(index * 2, value, Endian.little);
  }
  return bytes;
}
