enum ChannelType { chat, translator, agent }

extension ChannelTypeLabel on ChannelType {
  String get label => switch (this) {
    ChannelType.chat => 'CHAT',
    ChannelType.translator => 'TRANSLATOR',
    ChannelType.agent => 'AGENT',
  };
}
