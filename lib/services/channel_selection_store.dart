import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:ai_remote/core/models/channel.dart';
import 'package:ai_remote/core/models/channel_type.dart';

abstract interface class ChannelSelectionStore {
  Future<String?> readSelectedChannelId();
  Future<void> writeSelectedChannelId(String channelId);
}

class SharedPreferencesChannelSelectionStore implements ChannelSelectionStore {
  static const _key = 'selected_channel_id';

  @override
  Future<String?> readSelectedChannelId() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key);
  }

  @override
  Future<void> writeSelectedChannelId(String channelId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, channelId);
  }
}

class MemoryChannelSelectionStore implements ChannelSelectionStore {
  MemoryChannelSelectionStore({this.selectedChannelId});

  String? selectedChannelId;

  @override
  Future<String?> readSelectedChannelId() async => selectedChannelId;

  @override
  Future<void> writeSelectedChannelId(String channelId) async {
    selectedChannelId = channelId;
  }
}

/// Persists user-created AI Remote project definitions separately from the
/// selected-channel pointer. Secrets and conversation content are not stored
/// here.
abstract interface class ChannelCatalogStore {
  Future<List<Channel>> readCustomChannels();
  Future<void> writeCustomChannels(List<Channel> channels);
}

class SharedPreferencesChannelCatalogStore implements ChannelCatalogStore {
  static const _key = 'custom_channels_v1';

  @override
  Future<List<Channel>> readCustomChannels() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_fromJson)
          .toList(growable: false);
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  @override
  Future<void> writeCustomChannels(List<Channel> channels) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(channels.map(_toJson).toList(growable: false)),
    );
  }

  static Map<String, String> _toJson(Channel channel) => {
    'id': channel.id,
    'name': channel.name,
    'type': channel.type.name,
    'description': channel.description,
    'instructions': channel.instructions,
  };

  static Channel _fromJson(Map<String, dynamic> json) {
    final type = ChannelType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => ChannelType.agent,
    );
    return Channel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: type,
      description: json['description'] as String,
      instructions: json['instructions'] as String,
    );
  }
}

class MemoryChannelCatalogStore implements ChannelCatalogStore {
  MemoryChannelCatalogStore([List<Channel>? channels])
    : channels = List<Channel>.from(channels ?? const []);

  List<Channel> channels;

  @override
  Future<List<Channel>> readCustomChannels() async =>
      List<Channel>.unmodifiable(channels);

  @override
  Future<void> writeCustomChannels(List<Channel> channels) async {
    this.channels = List<Channel>.from(channels);
  }
}
