import 'dart:async';
import 'dart:typed_data';

/// A recording match returned by a fingerprint provider such as ShazamKit.
/// [offset] is the position in the reference recording corresponding to the
/// first captured sample. It is what lets a chord timeline stay synchronized.
class TrackMatch {
  const TrackMatch({
    required this.recordingId,
    required this.title,
    required this.artist,
    required this.offset,
    required this.confidence,
    this.duration,
  });

  final String recordingId;
  final String title;
  final String artist;
  final Duration offset;
  final double confidence;
  final Duration? duration;
}

/// Hardware/provider-independent streaming contract for track recognition.
/// The phone feeds captured PCM; implementations may use ShazamKit, AcoustID,
/// or a private provider without exposing that choice to the rest of the app.
abstract interface class TrackRecognitionService {
  Future<TrackRecognitionSession> open({required int sampleRate});
}

abstract interface class TrackRecognitionSession {
  Stream<TrackMatch> get matches;

  void addPcm16(Uint8List bytes, {required Duration position});

  Future<void> close();
}

/// Deterministic provider used by tests and mock mode. It emits one match
/// after [matchAfterChunks] buffers, then keeps the stream open for updates.
class MockTrackRecognitionService implements TrackRecognitionService {
  MockTrackRecognitionService({
    this.matchAfterChunks = 3,
    this.match = const TrackMatch(
      recordingId: 'mock-recording',
      title: 'Demo Song',
      artist: 'AI Remote',
      offset: Duration.zero,
      confidence: 1,
    ),
  });

  final int matchAfterChunks;
  final TrackMatch match;

  @override
  Future<TrackRecognitionSession> open({required int sampleRate}) async {
    return _MockTrackRecognitionSession(
      matchAfterChunks: matchAfterChunks,
      match: match,
    );
  }
}

class _MockTrackRecognitionSession implements TrackRecognitionSession {
  _MockTrackRecognitionSession({
    required this.matchAfterChunks,
    required this.match,
  });

  final int matchAfterChunks;
  final TrackMatch match;
  final StreamController<TrackMatch> _controller =
      StreamController<TrackMatch>.broadcast();
  var _chunks = 0;
  var _closed = false;

  @override
  Stream<TrackMatch> get matches => _controller.stream;

  @override
  void addPcm16(Uint8List bytes, {required Duration position}) {
    if (_closed || bytes.isEmpty) return;
    _chunks++;
    if (_chunks == matchAfterChunks) _controller.add(match);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _controller.close();
  }
}
