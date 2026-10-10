import 'package:ai_remote/core/state/ai_remote_state.dart';
import 'package:flutter/foundation.dart';

class AiRemoteStateMachine extends ChangeNotifier {
  AiRemoteState _state = AiRemoteState.idle;
  String? _errorMessage;

  AiRemoteState get state => _state;
  String? get errorMessage => _errorMessage;

  static const Map<AiRemoteState, Set<AiRemoteState>> _allowed = {
    AiRemoteState.idle: {
      AiRemoteState.channelSelected,
      AiRemoteState.disconnected,
      AiRemoteState.error,
    },
    AiRemoteState.channelSelected: {
      AiRemoteState.idle,
      AiRemoteState.listening,
      AiRemoteState.processing,
      AiRemoteState.translating,
      AiRemoteState.disconnected,
      AiRemoteState.error,
    },
    AiRemoteState.listening: {
      AiRemoteState.processing,
      AiRemoteState.channelSelected,
      AiRemoteState.disconnected,
      AiRemoteState.error,
    },
    AiRemoteState.processing: {
      AiRemoteState.aiSpeaking,
      AiRemoteState.translating,
      AiRemoteState.channelSelected,
      AiRemoteState.disconnected,
      AiRemoteState.error,
    },
    AiRemoteState.translating: {
      AiRemoteState.aiSpeaking,
      AiRemoteState.channelSelected,
      AiRemoteState.disconnected,
      AiRemoteState.error,
    },
    AiRemoteState.aiSpeaking: {
      AiRemoteState.listening,
      AiRemoteState.channelSelected,
      AiRemoteState.disconnected,
      AiRemoteState.error,
    },
    AiRemoteState.error: {
      AiRemoteState.idle,
      AiRemoteState.channelSelected,
      AiRemoteState.disconnected,
    },
    AiRemoteState.disconnected: {
      AiRemoteState.idle,
      AiRemoteState.channelSelected,
      AiRemoteState.processing,
      AiRemoteState.translating,
      AiRemoteState.error,
    },
  };

  void transitionTo(AiRemoteState next) {
    if (next == _state) {
      return;
    }
    if (!(_allowed[_state]?.contains(next) ?? false)) {
      throw StateError('Invalid AI Remote transition: $_state -> $next');
    }
    _state = next;
    if (next != AiRemoteState.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void fail(Object error) {
    _errorMessage = _friendlyMessage(error);
    if (_state != AiRemoteState.error) {
      _state = AiRemoteState.error;
    }
    notifyListeners();
  }

  String _friendlyMessage(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty ? 'Si è verificato un errore.' : message;
  }
}
