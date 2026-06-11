import 'track.dart';

class PlaylistModel {
  final int? id;
  final String name;
  final List<Track> tracks;
  final DateTime createdAt;

  PlaylistModel({
    this.id,
    required this.name,
    this.tracks = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get trackCount => tracks.length;

  PlaylistModel copyWith({
    int? id,
    String? name,
    List<Track>? tracks,
    DateTime? createdAt,
  }) =>
      PlaylistModel(
        id: id ?? this.id,
        name: name ?? this.name,
        tracks: tracks ?? this.tracks,
        createdAt: createdAt ?? this.createdAt,
      );
}
