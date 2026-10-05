import 'dart:typed_data';

import 'package:ai_remote/music/chord_timeline.dart';
import 'package:ai_remote/music/track_recognition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timeline returns the latest chord at a recording position', () {
    final timeline = ChordTimeline(
      recordingId: 'song-1',
      bpm: 120,
      key: 'G',
      entries: const [
        ChordTimelineEntry(start: Duration(seconds: 4), label: 'D'),
        ChordTimelineEntry(start: Duration.zero, label: 'G'),
        ChordTimelineEntry(start: Duration(seconds: 8), label: 'Em'),
      ],
    );

    expect(timeline.at(Duration.zero)?.label, 'G');
    expect(timeline.at(const Duration(seconds: 5))?.label, 'D');
    expect(timeline.at(const Duration(seconds: 9))?.label, 'Em');
  });

  test('mock recognition emits a match after the configured buffers', () async {
    final service = MockTrackRecognitionService(matchAfterChunks: 2);
    final session = await service.open(sampleRate: 16000);
    final matches = <TrackMatch>[];
    final subscription = session.matches.listen(matches.add);
    final bytes = Uint8List.fromList([1, 2, 3, 4]);

    session.addPcm16(bytes, position: Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(matches, isEmpty);
    session.addPcm16(bytes, position: const Duration(milliseconds: 100));
    await Future<void>.delayed(Duration.zero);

    expect(matches.single.recordingId, 'mock-recording');
    expect(matches.single.offset, Duration.zero);
    await subscription.cancel();
    await session.close();
  });
}
