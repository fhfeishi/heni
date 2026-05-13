import '../media/media_item.dart';

class HeniPlaylist {
  const HeniPlaylist({
    required this.id,
    required this.name,
    required this.items,
    this.sourceDirectory,
  });

  final String id;
  final String name;
  final List<MediaItem> items;
  final String? sourceDirectory;

  HeniPlaylist copyWith({
    String? id,
    String? name,
    List<MediaItem>? items,
    String? sourceDirectory,
  }) {
    return HeniPlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      sourceDirectory: sourceDirectory ?? this.sourceDirectory,
    );
  }
}
