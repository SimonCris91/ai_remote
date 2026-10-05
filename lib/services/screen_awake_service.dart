import 'package:flutter/services.dart';

/// Keeps the phone display awake while a foreground interaction is active.
/// The wearable display remains controlled by its own firmware.
class ScreenAwakeService {
  const ScreenAwakeService();

  static const _channel = MethodChannel('com.airemote/screen_awake');

  Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } on MissingPluginException {
      // No-op in tests and on unsupported platforms.
    } on PlatformException {
      // Convenience only: never fail the active interaction.
    }
  }
}

/// Safe default for controller/unit-test construction before Flutter bindings
/// exist. The production factory injects [ScreenAwakeService].
class NoopScreenAwakeService extends ScreenAwakeService {
  const NoopScreenAwakeService();

  @override
  Future<void> setEnabled(bool enabled) async {}
}
