import 'package:ai_remote/core/state/ai_remote_state.dart';
import 'package:ai_remote/core/state/ai_remote_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiRemoteStateMachine', () {
    test('accepts the push-to-talk lifecycle', () {
      final machine = AiRemoteStateMachine();
      machine
        ..transitionTo(AiRemoteState.channelSelected)
        ..transitionTo(AiRemoteState.listening)
        ..transitionTo(AiRemoteState.processing)
        ..transitionTo(AiRemoteState.aiSpeaking)
        ..transitionTo(AiRemoteState.channelSelected);

      expect(machine.state, AiRemoteState.channelSelected);
    });

    test('accepts the translator lifecycle', () {
      final machine = AiRemoteStateMachine();
      machine
        ..transitionTo(AiRemoteState.channelSelected)
        ..transitionTo(AiRemoteState.listening)
        ..transitionTo(AiRemoteState.processing)
        ..transitionTo(AiRemoteState.translating)
        ..transitionTo(AiRemoteState.aiSpeaking)
        ..transitionTo(AiRemoteState.channelSelected);

      expect(machine.state, AiRemoteState.channelSelected);
    });

    test('rejects invalid transitions and exposes friendly errors', () {
      final machine = AiRemoteStateMachine();
      expect(
        () => machine.transitionTo(AiRemoteState.aiSpeaking),
        throwsStateError,
      );

      machine.fail(Exception('Microfono non disponibile'));
      expect(machine.state, AiRemoteState.error);
      expect(machine.errorMessage, 'Microfono non disponibile');
    });
  });
}
