class Artist {
  final int? id;
  final String name;
  final String? albumArt;
  final int trackCount;
  final int albumCount;

  Artist({
    this.id,
    required this.name,
    this.albumArt,
    required this.trackCount,
    required this.albumCount,
  });
}
