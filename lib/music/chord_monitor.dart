import 'dart:async';
import 'dart:math' as math;
import 'package:ai_remote/music/chord_analyzer.dart';
import 'package:ai_remote/music/chord_estimate.dart';
import 'package:ai_remote/music/chord_progression_predictor.dart';
import 'package:ai_remote/music/system_audio_capture.dart';
import 'package:ai_remote/music/rhythm_tracker.dart';
import 'package:ai_remote/music/chord_timeline.dart';
import 'package:ai_remote/music/track_recognition.dart';
import 'package:flutter/foundation.dart';

class ChordMonitorController extends ChangeNotifier {
  ChordMonitorController({
    required this._capture,
    required this._analyzer,
    this.trackRecognition,
    this.chordTimelineService,
    this.sampleRate = 24000,
  });

  // A fixed refresh cadence is easier to follow by ear than a user-controlled
  // ten-step speed selector. Tempo estimation and beat alignment are handled
  // separately by RhythmTracker.
  static const Duration _fixedAnalysisInterval = Duration(milliseconds: 280);

  final AudioPlaybackCapture _capture;
  final ChordAnalyzer _analyzer;
  final TrackRecognitionService? trackRecognition;
  final ChordTimelineService? chordTimelineService;
  final int sampleRate;
  final ChordProgressionPredictor progression = ChordProgressionPredictor();
  final RhythmTracker rhythm = RhythmTracker();
  StreamSubscription<Uint8List>? _subscription;
  StreamSubscription<TrackMatch>? _matchSubscription;
  TrackRecognitionSession? _recognitionSession;
  ChordEstimate? _current;
  ChordEstimate? _latestLocalEstimate;
  TrackMatch? _recognizedTrack;
  ChordTimeline? _chordTimeline;
  Duration _capturePosition = Duration.zero;
  var _recognitionGeneration = 0;
  String? _errorMessage;
  bool _isRunning = false;
  bool _disposed = false;

  ChordEstimate? get current => _current;
  String? get errorMessage => _errorMessage;
  bool get isRunning => _isRunning;
  String? get predictedNextChord => progression.predictedNext;
  double? get bpm => rhythm.bpm;
  TrackMatch? get recognizedTrack => _recognizedTrack;
  ChordTimeline? get chordTimeline => _chordTimeline;

  Duration get refreshInterval => _fixedAnalysisInterval;
  String get speedLabel => 'AUTO';

  String get speedDescription =>
      'Aggiornamento automatico · ~${refreshInterval.inMilliseconds} ms';

  void slower() {}

  void faster() {}

  Future<void> start() async {
    if (_isRunning) return;
    _errorMessage = null;
    _current = null;
    _latestLocalEstimate = null;
    _recognizedTrack = null;
    _chordTimeline = null;
    _capturePosition = Duration.zero;
    progression.reset();
    rhythm.reset();
    _analyzer.reset();
    try {
      await _openRecognition();
      // Subscribe before requesting Android consent so the first PCM packets
      // are not lost when capture starts immediately after the dialog.
      _subscription = _capture.pcm16Stream.listen(
        _onChunk,
        onError: (Object e) {
          _errorMessage = 'Cattura audio interrotta: $e';
          _isRunning = false;
          _current = null;
          notifyListeners();
        },
      );
      await _capture.start();
      _isRunning = true;
      notifyListeners();
    } catch (error) {
      await _subscription?.cancel();
      _subscription = null;
      await _closeRecognition();
      _errorMessage = _friendlyError(error);
      _isRunning = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stop() async {
    _recognitionGeneration++;
    await _subscription?.cancel();
    _subscription = null;
    await _closeRecognition();
    await _capture.stop();
    _isRunning = false;
    _current = null;
    _latestLocalEstimate = null;
    _recognizedTrack = null;
    _chordTimeline = null;
    _capturePosition = Duration.zero;
    progression.reset();
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _onChunk(Uint8List chunk) {
    if (_disposed) return;
    _recognitionSession?.addPcm16(chunk, position: _capturePosition);
    rhythm.addPcm16(chunk, sampleRate: sampleRate);
    final estimate = _analyzer.addPcm16(chunk, sampleRate: sampleRate);
    _capturePosition += Duration(
      microseconds: (chunk.length * 1000000 / (sampleRate * 2)).round(),
    );
    if (estimate == null) return;
    _latestLocalEstimate = estimate;
    final visibleEstimate = _timelineEstimate(estimate);
    final current = _current;
    if (current != null &&
        current.label != visibleEstimate.label &&
        !rhythm.isNearBeat(visibleEstimate.position)) {
      return;
    }
    _current = visibleEstimate;
    progression.observe(visibleEstimate);
    notifyListeners();
  }

  Future<void> _openRecognition() async {
    final service = trackRecognition;
    if (service == null) return;
    final generation = ++_recognitionGeneration;
    try {
      final session = await service.open(sampleRate: sampleRate);
      if (_disposed || generation != _recognitionGeneration) {
        await session.close();
        return;
      }
      _recognitionSession = session;
      _matchSubscription = session.matches.listen(
        (match) => unawaited(_acceptMatch(match, generation)),
        onError: (Object error) {
          if (generation != _recognitionGeneration || _disposed) return;
          _errorMessage = 'Riconoscimento brano non disponibile: $error';
          notifyListeners();
        },
      );
    } catch (error) {
      // Recognition is an enhancement. Local chord analysis must continue if
      // the provider is unavailable or not configured yet.
      _errorMessage = 'Riconoscimento brano non disponibile: $error';
      notifyListeners();
    }
  }

  Future<void> _acceptMatch(TrackMatch match, int generation) async {
    if (_disposed || generation != _recognitionGeneration) return;
    _recognizedTrack = match;
    _chordTimeline = null;
    final service = chordTimelineService;
    if (service != null) {
      try {
        _chordTimeline = await service.forTrack(match);
      } catch (error) {
        _errorMessage = 'Timeline accordi non disponibile: $error';
      }
    }
    if (_disposed || generation != _recognitionGeneration) return;
    final latest = _latestLocalEstimate;
    if (latest != null && _chordTimeline != null) {
      final visible = _timelineEstimate(latest);
      _current = visible;
      progression.observe(visible);
    }
    notifyListeners();
  }

  ChordEstimate _timelineEstimate(ChordEstimate estimate) {
    final match = _recognizedTrack;
    final timeline = _chordTimeline;
    if (match == null || timeline == null) return estimate;
    final entry = timeline.at(match.offset + estimate.position);
    if (entry == null || entry.label == estimate.label) return estimate;
    return ChordEstimate(
      label: entry.label,
      confidence: math.max(estimate.confidence, 0.98),
      position: estimate.position,
    );
  }

  Future<void> _closeRecognition() async {
    await _matchSubscription?.cancel();
    _matchSubscription = null;
    final session = _recognitionSession;
    _recognitionSession = null;
    await session?.close();
  }

  String _friendlyError(Object error) {
    if (error.toString().contains('permission')) {
      return 'Autorizzazione Android per catturare l’audio non concessa.';
    }
    return 'Analisi audio non disponibile: $error';
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(stop());
    unawaited(_capture.dispose());
    super.dispose();
  }
}
