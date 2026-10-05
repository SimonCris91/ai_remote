import 'package:ai_remote/channels/channel_manager.dart';
import 'package:ai_remote/core/models/conversation_message.dart';
import 'package:ai_remote/services/channel_selection_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChannelManager', () {
    test('restores and persists the selected channel', () async {
      final store = MemoryChannelSelectionStore(
        selectedChannelId: 'translator',
      );
      final manager = ChannelManager(selectionStore: store);

      await manager.initialize();
      expect(manager.selectedChannel.id, 'translator');

      await manager.next();
      expect(manager.selectedChannel.id, 'lavormetal-daily');

      final restored = ChannelManager(selectionStore: store);
      await restored.initialize();
      expect(restored.selectedChannel.id, 'lavormetal-daily');
    });

    test('previous and next wrap through the ordered list', () async {
      final manager = ChannelManager(
        selectionStore: MemoryChannelSelectionStore(),
      );
      await manager.initialize();

      await manager.previous();
      expect(manager.selectedChannel.id, 'technical-agent');
      await manager.next();
      expect(manager.selectedChannel.id, 'general-chat');
    });

    test('keeps conversation context isolated per channel', () async {
      final manager = ChannelManager(
        selectionStore: MemoryChannelSelectionStore(),
      );
      await manager.initialize();
      manager.addMessage(
        'general-chat',
        ConversationMessage(role: ConversationRole.user, content: 'Ciao'),
      );

      await manager.next();
      expect(manager.selectedSession.messages, isEmpty);
      manager.addMessage(
        'translator',
        ConversationMessage(role: ConversationRole.user, content: 'Hello'),
      );

      expect(
        manager.sessionFor('general-chat').messages.single.content,
        'Ciao',
      );
      expect(manager.sessionFor('translator').messages.single.content, 'Hello');
      expect(manager.sessionFor('technical-agent').messages, isEmpty);
    });

    test('includes the isolated LavorMetal daily project channel', () async {
      final manager = ChannelManager(
        selectionStore: MemoryChannelSelectionStore(
          selectedChannelId: 'lavormetal-daily',
        ),
      );
      await manager.initialize();

      expect(manager.selectedChannel.name, 'LavorMetal · Attività giornaliere');
      expect(manager.selectedChannel.description, contains('Telegram'));
      expect(manager.selectedSession.messages, isEmpty);
    });
  });
}
