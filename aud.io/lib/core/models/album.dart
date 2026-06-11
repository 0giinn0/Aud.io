class Album {
  final String id;
  final String title;
  final String? artist;
  final String? thumbnailUrl;
  final int trackCount;

  Album({
    required this.id,
    required this.title,
    this.artist,
    this.thumbnailUrl,
    this.trackCount = 0,
  });
}
