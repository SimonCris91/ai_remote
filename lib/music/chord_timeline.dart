import 'track_recognition.dart';

/// A timestamped chord from a licensed/imported chord source.
class ChordTimelineEntry {
  const ChordTimelineEntry({required this.start, required this.label});

  final Duration start;
  final String label;
}

/// Chords aligned to one exact recording, not merely a song title.
class ChordTimeline {
  ChordTimeline({
    required this.recordingId,
    required List<ChordTimelineEntry> entries,
    this.bpm,
    this.key,
  }) : entries = List.unmodifiable(
         [...entries]..sort((a, b) => a.start.compareTo(b.start)),
       ),
       assert(entries.isNotEmpty);

  final String recordingId;
  final List<ChordTimelineEntry> entries;
  final double? bpm;
  final String? key;

  ChordTimelineEntry? at(Duration recordingPosition) {
    ChordTimelineEntry? current;
    for (final entry in entries) {
      if (entry.start > recordingPosition) break;
      current = entry;
    }
    return current;
  }
}

abstract interface class ChordTimelineService {
  Future<ChordTimeline?> forTrack(TrackMatch match);
}

/// In-memory catalog for mock mode and deterministic tests. A production
/// adapter can read a licensed catalog or an imported user-owned file.
class MockChordTimelineService implements ChordTimelineService {
  MockChordTimelineService({Map<String, ChordTimeline> timelines = const {}})
    : _timelines = Map.unmodifiable(timelines);

  final Map<String, ChordTimeline> _timelines;

  @override
  Future<ChordTimeline?> forTrack(TrackMatch match) async {
    return _timelines[match.recordingId];
  }
}
