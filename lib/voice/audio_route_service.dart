enum AudioRoute { systemDefault, phoneSpeaker, bluetooth }

abstract interface class AudioRouteService {
  AudioRoute get preferredRoute;
  Future<void> prefer(AudioRoute route);
}

/// MVP behavior: let Android route audio to the currently selected system
/// device. A platform adapter can replace this without changing voice logic.
class SystemAudioRouteService implements AudioRouteService {
  AudioRoute _preferredRoute = AudioRoute.systemDefault;

  @override
  AudioRoute get preferredRoute => _preferredRoute;

  @override
  Future<void> prefer(AudioRoute route) async {
    _preferredRoute = route;
  }
}
