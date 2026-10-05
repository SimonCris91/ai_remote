import 'package:ai_remote/core/models/channel.dart';
import 'package:ai_remote/core/models/channel_type.dart';
import 'package:ai_remote/core/models/conversation_message.dart';
import 'package:ai_remote/core/models/conversation_session.dart';
import 'package:ai_remote/services/channel_selection_store.dart';
import 'package:flutter/foundation.dart';

class ChannelManager extends ChangeNotifier {
  ChannelManager({
    required this.selectionStore,
    List<Channel>? channels,
    ChannelCatalogStore? catalogStore,
  }) : _channels = List<Channel>.from(channels ?? defaultChannels),
       catalogStore = catalogStore ?? MemoryChannelCatalogStore() {
    if (_channels.isEmpty) {
      throw ArgumentError.value(channels, 'channels', 'Cannot be empty');
    }
    for (final channel in _channels) {
      _sessions[channel.id] = ConversationSession(channelId: channel.id);
    }
  }

  static const List<Channel> defaultChannels = [
    Channel(
      id: 'general-chat',
      name: 'General Chat',
      type: ChannelType.chat,
      description: 'Conversazione quotidiana',
      instructions: 'Be a concise, helpful general voice assistant.',
    ),
    Channel(
      id: 'translator',
      name: 'Translator',
      type: ChannelType.translator,
      description: 'Italiano ↔ Inglese',
      instructions: 'Translate faithfully without adding commentary.',
    ),
    Channel(
      id: 'lavormetal-daily',
      name: 'LavorMetal · Attività giornaliere',
      type: ChannelType.agent,
      description: 'Report operativi pronti per Telegram',
      instructions:
          'Sei l’assistente operativo di LavorMetal. Trasforma appunti grezzi in report giornalieri compatti, pronti per Telegram. Organizza data e luogo, attività per persona, materiali, attrezzature, problemi, sospensioni e osservazioni. Non inventare persone, quantità, codici o attività mancanti: indica solo i dati disponibili e segnala ciò che va confermato. Rispondi in italiano.',
    ),
    Channel(
      id: 'technical-agent',
      name: 'Technical Agent',
      type: ChannelType.agent,
      description: 'Supporto tecnico operativo',
      instructions:
          'Act as a practical technical assistant. Give safe, concise steps.',
    ),
  ];

  final ChannelSelectionStore selectionStore;
  final ChannelCatalogStore catalogStore;
  final List<Channel> _channels;
  final Map<String, ConversationSession> _sessions = {};
  int _selectedIndex = 0;

  List<Channel> get channels => _channels;
  int get selectedIndex => _selectedIndex;
  Channel get selectedChannel => _channels[_selectedIndex];
  ConversationSession get selectedSession => sessionFor(selectedChannel.id);

  Future<void> initialize() async {
    final customChannels = await catalogStore.readCustomChannels();
    for (final channel in customChannels) {
      if (_channels.every((candidate) => candidate.id != channel.id)) {
        _channels.add(channel);
        _sessions[channel.id] = ConversationSession(channelId: channel.id);
      }
    }
    final savedId = await selectionStore.readSelectedChannelId();
    final savedIndex = _channels.indexWhere((channel) => channel.id == savedId);
    _selectedIndex = savedIndex >= 0 ? savedIndex : 0;
    notifyListeners();
  }

  Future<Channel> previous() async {
    _selectedIndex = (_selectedIndex - 1 + _channels.length) % _channels.length;
    await _persistSelection();
    notifyListeners();
    return selectedChannel;
  }

  Future<Channel> next() async {
    _selectedIndex = (_selectedIndex + 1) % _channels.length;
    await _persistSelection();
    notifyListeners();
    return selectedChannel;
  }

  ConversationSession activate() => selectedSession;

  ConversationSession sessionFor(String channelId) {
    final session = _sessions[channelId];
    if (session == null) {
      throw ArgumentError.value(channelId, 'channelId', 'Unknown channel');
    }
    return session;
  }

  Future<Channel> createChat(String name, {String? instructions}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw ArgumentError.value(name, 'name');
    final id = 'chat-${DateTime.now().microsecondsSinceEpoch}';
    final channel = Channel(
      id: id,
      name: cleanName,
      type: ChannelType.agent,
      description: 'Chat personale',
      instructions: (instructions?.trim().isNotEmpty ?? false)
          ? instructions!.trim()
          : 'Sei un assistente personale. Rispondi in italiano, mantieni il contesto di questa chat e non inventare informazioni.',
    );
    _channels.add(channel);
    _sessions[id] = ConversationSession(channelId: id);
    await _persistCustomChannels();
    _selectedIndex = _channels.length - 1;
    await _persistSelection();
    notifyListeners();
    return channel;
  }

  Future<void> deleteChat(String channelId) async {
    if (defaultChannels.any((channel) => channel.id == channelId)) {
      throw StateError('I canali base non possono essere eliminati.');
    }
    final index = _channels.indexWhere((channel) => channel.id == channelId);
    if (index < 0) return;
    _channels.removeAt(index);
    _sessions.remove(channelId);
    _selectedIndex = _selectedIndex.clamp(0, _channels.length - 1);
    await _persistCustomChannels();
    await _persistSelection();
    notifyListeners();
  }

  Future<void> _persistCustomChannels() => catalogStore.writeCustomChannels(
    _channels.where((channel) => !defaultChannels.contains(channel)).toList(),
  );

  void addMessage(String channelId, ConversationMessage message) {
    sessionFor(channelId).add(message);
    notifyListeners();
  }

  Future<void> _persistSelection() =>
      selectionStore.writeSelectedChannelId(selectedChannel.id);
}
