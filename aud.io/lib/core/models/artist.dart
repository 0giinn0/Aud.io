enum ArtistSource { itunes, lastfm }

class Artist {
  final String id;
  final String name;
  final String? image;
  final ArtistSource source;
  final String? genre;
  final String? link;
  final String? bio;
  final int listeners;
  final int playcount;

  Artist({
    required this.id,
    required this.name,
    this.image,
    this.source = ArtistSource.itunes,
    this.genre,
    this.link,
    this.bio,
    this.listeners = 0,
    this.playcount = 0,
  });

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        image: json['image'],
        source: json['source'] == 'lastfm'
            ? ArtistSource.lastfm
            : ArtistSource.itunes,
        genre: json['genre'],
        link: json['link'],
        bio: json['bio'],
        listeners: json['listeners'] ?? 0,
        playcount: json['playcount'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image': image,
        'source': source.name,
        'genre': genre,
        'link': link,
        'bio': bio,
        'listeners': listeners,
        'playcount': playcount,
      };

  String get sourceLabel {
    switch (source) {
      case ArtistSource.itunes:
        return 'iTunes';
      case ArtistSource.lastfm:
        return 'Last.fm';
    }
  }

  String get listenersDisplay {
    if (listeners >= 1000000) {
      return '${(listeners / 1000000).toStringAsFixed(1)}M';
    }
    if (listeners >= 1000) {
      return '${(listeners / 1000).toStringAsFixed(1)}K';
    }
    return listeners.toString();
  }

  String get playcountDisplay {
    if (playcount >= 1000000) {
      return '${(playcount / 1000000).toStringAsFixed(1)}M';
    }
    if (playcount >= 1000) {
      return '${(playcount / 1000).toStringAsFixed(1)}K';
    }
    return playcount.toString();
  }
}
