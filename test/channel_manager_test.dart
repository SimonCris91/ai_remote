import 'package:ai_remote/channels/channel_manager.dart';
import 'package:ai_remote/core/models/conversation_message.dart';
import 'package:ai_remote/services/channel_selection_store.dart';
import 'package:ai_remote/services/conversation_store.dart';
import 'package:ai_remote/services/sqlite_conversation_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

void main() {
  setUpAll(sqfliteFfiInit);

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
      expect(manager.selectedChannel.id, 'lumen-system');
      await manager.next();
      expect(manager.selectedChannel.id, 'general-chat');
    });

    test('keeps conversation context isolated per channel', () async {
      final manager = ChannelManager(
        selectionStore: MemoryChannelSelectionStore(),
      );
      await manager.initialize();
      await manager.addMessages('general-chat', [
        ConversationMessage(role: ConversationRole.user, content: 'Ciao'),
      ]);

      await manager.next();
      expect(manager.selectedSession.messages, isEmpty);
      await manager.addMessages('translator', [
        ConversationMessage(role: ConversationRole.user, content: 'Hello'),
      ]);

      expect(
        manager.sessionFor('general-chat').messages.single.content,
        'Ciao',
      );
      expect(manager.sessionFor('translator').messages.single.content, 'Hello');
      expect(manager.sessionFor('technical-agent').messages, isEmpty);
    });

    test('restores independent conversation histories after restart', () async {
      final store = MemoryConversationStore();
      final firstRun = ChannelManager(
        selectionStore: MemoryChannelSelectionStore(),
        conversationStore: store,
      );
      await firstRun.initialize();
      await firstRun.addMessages('general-chat', [
        ConversationMessage(role: ConversationRole.user, content: 'Ciao'),
        ConversationMessage(
          role: ConversationRole.assistant,
          content: 'Dimmi pure',
        ),
      ]);
      await firstRun.addMessages('technical-agent', [
        ConversationMessage(role: ConversationRole.user, content: 'Bug'),
      ]);
      await firstRun.saveCodexThreadId('technical-agent', 'thread-xyz');

      final restarted = ChannelManager(
        selectionStore: MemoryChannelSelectionStore(),
        conversationStore: store,
      );
      await restarted.initialize();

      expect(restarted.sessionFor('general-chat').messages, hasLength(2));
      expect(
        restarted.sessionFor('general-chat').messages.last.content,
        'Dimmi pure',
      );
      expect(
        restarted.sessionFor('technical-agent').messages.single.content,
        'Bug',
      );
      expect(
        restarted.sessionFor('technical-agent').codexThreadId,
        'thread-xyz',
      );
      expect(restarted.sessionFor('translator').messages, isEmpty);
    });

    test('SQLite conversation database survives store recreation', () async {
      final directory = await Directory.systemTemp.createTemp(
        'ai_remote_conversations_',
      );
      final path = '${directory.path}${Platform.pathSeparator}test.db';
      final firstStore = SqliteConversationStore(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      await firstStore.appendMessages('general-chat', [
        ConversationMessage(
          role: ConversationRole.user,
          content: 'Messaggio conservato',
          createdAt: DateTime.utc(2026, 10, 7, 12),
        ),
      ]);
      await firstStore.saveCodexThreadId('technical-agent', 'thread-abc');
      await firstStore.close();

      final reopenedStore = SqliteConversationStore(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final messages = await reopenedStore.readAllMessages();

      expect(messages['general-chat'], hasLength(1));
      expect(messages['general-chat']!.single.content, 'Messaggio conservato');
      expect(
        messages['general-chat']!.single.createdAt,
        DateTime.utc(2026, 10, 7, 12),
      );
      expect(await reopenedStore.readCodexThreadIds(), {
        'technical-agent': 'thread-abc',
      });
      await reopenedStore.close();
      await directory.delete(recursive: true);
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

    test('includes a read-only LumenSystem activity channel', () async {
      final manager = ChannelManager(
        selectionStore: MemoryChannelSelectionStore(
          selectedChannelId: 'lumen-system',
        ),
      );
      await manager.initialize();

      expect(manager.selectedChannel.name, 'LumenSystem');
      expect(manager.selectedChannel.description, contains('sola lettura'));
      expect(manager.selectedSession.messages, isEmpty);
    });
  });
}
