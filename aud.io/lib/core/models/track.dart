enum TrackSource { youtube, soundcloud, fma, local, fake }

class Track {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final String? thumbnailUrl;
  String? audioUrl;
  final int duration;
  final TrackSource source;
  final String? license;
  final String? artistUrl;

  Track({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.thumbnailUrl,
    this.audioUrl,
    this.duration = 0,
    this.source = TrackSource.fake,
    this.license,
    this.artistUrl,
  });

  factory Track.fromLocalFile(dynamic file) {
    final path = file.path as String;
    final name = path.split('/').last;
    final baseName = name.substring(0, name.lastIndexOf('.'));
    return Track(
      id: 'local_${path.hashCode}',
      title: baseName,
      artist: 'Local',
      album: 'Device',
      audioUrl: path,
      duration: 0,
      source: TrackSource.local,
    );
  }

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        artist: json['artist'],
        album: json['album'],
        thumbnailUrl: json['thumbnailUrl'],
        audioUrl: json['audioUrl'],
        duration: json['duration'] ?? 0,
        source: TrackSource.values.firstWhere(
          (e) => e.name == json['source'],
          orElse: () => TrackSource.fake,
        ),
        license: json['license'],
        artistUrl: json['artistUrl'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'thumbnailUrl': thumbnailUrl,
        'audioUrl': audioUrl,
        'duration': duration,
        'source': source.name,
        'license': license,
        'artistUrl': artistUrl,
      };

  String get displayDuration {
    final d = Duration(seconds: duration);
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get artistDisplay => artist ?? 'Unknown Artist';
  String get albumDisplay => album ?? 'aud.io';
  String get sourceLabel {
    switch (source) {
      case TrackSource.youtube: return 'YouTube';
      case TrackSource.soundcloud: return 'SoundCloud';
      case TrackSource.fma: return 'Free Music Archive';
      case TrackSource.local: return 'Local';
      case TrackSource.fake: return 'Demo';
    }
  }

  String get sourceShort {
    switch (source) {
      case TrackSource.youtube: return 'YT';
      case TrackSource.soundcloud: return 'SC';
      case TrackSource.fma: return 'FMA';
      case TrackSource.local: return 'LOCAL';
      case TrackSource.fake: return 'DEMO';
    }
  }

  bool get isFma => source == TrackSource.fma;
  bool get hasLicense => license != null && license!.isNotEmpty;
}
