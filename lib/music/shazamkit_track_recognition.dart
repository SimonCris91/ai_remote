import 'dart:async';

import 'package:flutter/services.dart';

import 'track_recognition.dart';

/// Flutter-side bridge for the native ShazamKit Android adapter.
///
/// The native side is intentionally optional: if the ShazamKit AAR or a
/// server-issued developer token is not configured, opening the session fails
/// and ChordMonitorController keeps using its local analyzer.
class ShazamKitTrackRecognitionService implements TrackRecognitionService {
  ShazamKitTrackRecognitionService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel = methodChannel ?? _defaultMethodChannel,
       _eventChannel = eventChannel ?? _defaultEventChannel;

  static const _defaultMethodChannel = MethodChannel(
    'com.airemote/shazamkit_recognition',
  );
  static const _defaultEventChannel = EventChannel(
    'com.airemote/shazamkit_recognition/events',
  );

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  @override
  Future<TrackRecognitionSession> open({required int sampleRate}) async {
    final sessionId = await _methodChannel.invokeMethod<String>('open', {
      'sampleRate': sampleRate,
    });
    if (sessionId == null || sessionId.isEmpty) {
      throw StateError('ShazamKit non ha restituito un sessionId.');
    }
    return _ShazamKitSession(
      sessionId: sessionId,
      methodChannel: _methodChannel,
      eventChannel: _eventChannel,
    );
  }
}

class _ShazamKitSession implements TrackRecognitionSession {
  _ShazamKitSession({
    required this.sessionId,
    required this.methodChannel,
    required EventChannel eventChannel,
  }) {
    _subscription = eventChannel
        .receiveBroadcastStream({'sessionId': sessionId})
        .listen(_onEvent, onError: _controller.addError);
  }

  final String sessionId;
  final MethodChannel methodChannel;
  final StreamController<TrackMatch> _controller =
      StreamController<TrackMatch>.broadcast();
  late final StreamSubscription<dynamic> _subscription;
  var _closed = false;

  @override
  Stream<TrackMatch> get matches => _controller.stream;

  @override
  void addPcm16(Uint8List bytes, {required Duration position}) {
    if (_closed || bytes.isEmpty) return;
    unawaited(
      methodChannel.invokeMethod<void>('push', {
        'sessionId': sessionId,
        'audio': bytes,
        'positionMs': position.inMilliseconds,
      }),
    );
  }

  void _onEvent(dynamic event) {
    if (_closed || event is! Map) return;
    final recordingId = event['recordingId'];
    final title = event['title'];
    final artist = event['artist'];
    final offsetMs = event['offsetMs'];
    final confidence = event['confidence'];
    if (recordingId is! String ||
        title is! String ||
        artist is! String ||
        offsetMs is! num ||
        confidence is! num) {
      return;
    }
    final durationMs = event['durationMs'];
    _controller.add(
      TrackMatch(
        recordingId: recordingId,
        title: title,
        artist: artist,
        offset: Duration(milliseconds: offsetMs.round()),
        confidence: confidence.toDouble().clamp(0.0, 1.0).toDouble(),
        duration: durationMs is num
            ? Duration(milliseconds: durationMs.round())
            : null,
      ),
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription.cancel();
    await methodChannel.invokeMethod<void>('close', {'sessionId': sessionId});
    await _controller.close();
  }
}
