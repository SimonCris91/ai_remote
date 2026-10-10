import 'dart:io';

import 'package:ai_remote/core/models/conversation_message.dart';
import 'package:ai_remote/services/conversation_store.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite-backed, on-device conversation storage.
///
/// The database stays in the app-private data directory. It is not synchronized
/// to a server; add a separate consented sync service for future web analytics.
class SqliteConversationStore implements ConversationStore {
  SqliteConversationStore({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactory,
      _databasePathOverride = databasePath;

  static const _fileName = 'ai_remote.db';
  final DatabaseFactory _factory;
  final String? _databasePathOverride;
  Future<Database>? _databaseFuture;

  Future<Database> get _database => _databaseFuture ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final path =
        _databasePathOverride ??
        '${await getDatabasesPath()}${Platform.pathSeparator}$_fileName';
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE conversation_messages (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              channel_id TEXT NOT NULL,
              role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
              content TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await database.execute('''
            CREATE INDEX conversation_messages_by_channel
            ON conversation_messages(channel_id, id)
          ''');
          await database.execute('''
            CREATE TABLE codex_threads (
              channel_id TEXT PRIMARY KEY,
              thread_id TEXT NOT NULL
            )
          ''');
        },
        onUpgrade: (database, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await database.execute('''
              CREATE TABLE codex_threads (
                channel_id TEXT PRIMARY KEY,
                thread_id TEXT NOT NULL
              )
            ''');
          }
        },
      ),
    );
  }

  @override
  Future<Map<String, List<ConversationMessage>>> readAllMessages() async {
    final rows = await (await _database).query(
      'conversation_messages',
      columns: ['channel_id', 'role', 'content', 'created_at'],
      orderBy: 'id ASC',
    );
    final result = <String, List<ConversationMessage>>{};
    for (final row in rows) {
      final channelId = row['channel_id'] as String;
      final role = ConversationRole.values.byName(row['role'] as String);
      final createdAt = DateTime.parse(row['created_at'] as String);
      result
          .putIfAbsent(channelId, () => <ConversationMessage>[])
          .add(
            ConversationMessage(
              role: role,
              content: row['content'] as String,
              createdAt: createdAt,
            ),
          );
    }
    return result;
  }

  @override
  Future<Map<String, String>> readCodexThreadIds() async {
    final rows = await (await _database).query('codex_threads');
    return {
      for (final row in rows)
        row['channel_id'] as String: row['thread_id'] as String,
    };
  }

  @override
  Future<void> saveCodexThreadId(String channelId, String threadId) async {
    await (await _database).insert('codex_threads', {
      'channel_id': channelId,
      'thread_id': threadId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> appendMessages(
    String channelId,
    List<ConversationMessage> messages,
  ) async {
    if (messages.isEmpty) return;
    final database = await _database;
    await database.transaction((transaction) async {
      for (final message in messages) {
        await transaction.insert('conversation_messages', {
          'channel_id': channelId,
          'role': message.role.name,
          'content': message.content,
          'created_at': message.createdAt.toIso8601String(),
        });
      }
    });
  }

  @override
  Future<void> deleteChannel(String channelId) async {
    final database = await _database;
    await database.transaction((transaction) async {
      await transaction.delete(
        'conversation_messages',
        where: 'channel_id = ?',
        whereArgs: [channelId],
      );
      await transaction.delete(
        'codex_threads',
        where: 'channel_id = ?',
        whereArgs: [channelId],
      );
    });
  }

  Future<void> close() async {
    final databaseFuture = _databaseFuture;
    _databaseFuture = null;
    if (databaseFuture != null) await (await databaseFuture).close();
  }
}
