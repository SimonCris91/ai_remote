enum AiRemoteState {
  idle,
  channelSelected,
  listening,
  processing,
  aiSpeaking,
  translating,
  error,
  disconnected,
}

extension AiRemoteStateLabel on AiRemoteState {
  String get label => switch (this) {
    AiRemoteState.idle => 'IDLE',
    AiRemoteState.channelSelected => 'CHANNEL SELECTED',
    AiRemoteState.listening => 'LISTENING',
    AiRemoteState.processing => 'PROCESSING',
    AiRemoteState.aiSpeaking => 'AI SPEAKING',
    AiRemoteState.translating => 'TRANSLATING',
    AiRemoteState.error => 'ERROR',
    AiRemoteState.disconnected => 'DISCONNECTED',
  };
}
