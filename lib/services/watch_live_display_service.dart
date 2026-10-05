import 'package:flutter/services.dart';

class WatchLiveDisplayService {
  const WatchLiveDisplayService();

  static const _channel = MethodChannel('com.airemote/watch_display');

  Future<void> update({
    required String title,
    required String subtitle,
    required String content,
  }) async {
    try {
      await _channel.invokeMethod<void>('update', <String, String>{
        'title': title,
        'subtitle': subtitle,
        'content': content,
      });
    } on MissingPluginException {
      // No-op outside Android.
    } on PlatformException {
      // A notification is a convenience and must not break the monitor.
    }
  }

  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      // No-op outside Android.
    } on PlatformException {
      // Ignore notification cleanup failures.
    }
  }
}

class NoopWatchLiveDisplayService extends WatchLiveDisplayService {
  const NoopWatchLiveDisplayService();

  @override
  Future<void> update({
    required String title,
    required String subtitle,
    required String content,
  }) async {}

  @override
  Future<void> clear() async {}
}
