import 'package:ai_remote/core/models/channel_type.dart';

class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.instructions,
  });

  final String id;
  final String name;
  final ChannelType type;
  final String description;
  final String instructions;
}
