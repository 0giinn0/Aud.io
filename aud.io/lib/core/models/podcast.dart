class PodcastEpisode {
  final String id;
  final String title;
  final String? artist;
  final String? podcastId;
  final String? podcastTitle;
  final String? podcastAuthor;
  final String? thumbnailUrl;
  final String? audioUrl;
  final int duration;
  final String? description;
  final int publishDate;

  PodcastEpisode({
    required this.id,
    required this.title,
    this.artist,
    this.podcastId,
    this.podcastTitle,
    this.podcastAuthor,
    this.thumbnailUrl,
    this.audioUrl,
    this.duration = 0,
    this.description,
    this.publishDate = 0,
  });

  factory PodcastEpisode.fromJson(Map<String, dynamic> json) => PodcastEpisode(
        id: (json['id'] ?? '').toString(),
        title: json['title'] ?? 'Unknown Episode',
        artist: json['artist'] ?? json['podcastTitle'] ?? 'Unknown Podcast',
        podcastId: json['podcastId']?.toString(),
        podcastTitle: json['podcastTitle'],
        podcastAuthor: json['podcastAuthor'],
        thumbnailUrl: json['thumbnail'] ?? json['thumbnailUrl'],
        audioUrl: json['audio'] ?? json['audioUrl'],
        duration: json['duration'] ?? json['audio_length_sec'] ?? 0,
        description: json['description'],
        publishDate: json['publishDate'] ?? json['pub_date_ms'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'podcastId': podcastId,
        'podcastTitle': podcastTitle,
        'podcastAuthor': podcastAuthor,
        'thumbnailUrl': thumbnailUrl,
        'audioUrl': audioUrl,
        'duration': duration,
        'description': description,
        'publishDate': publishDate,
      };

  String get displayDuration {
    final d = Duration(seconds: duration);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get publishDateDisplay {
    if (publishDate == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(publishDate);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String get artistDisplay => podcastAuthor ?? artist ?? 'Unknown Podcast';
  String get podcastDisplay => podcastTitle ?? 'Podcast';
}

class Podcast {
  final String id;
  final String title;
  final String? author;
  final String? description;
  final String? thumbnailUrl;
  final String? feedUrl;
  final int episodeCount;
  final List<PodcastEpisode> episodes;

  Podcast({
    required this.id,
    required this.title,
    this.author,
    this.description,
    this.thumbnailUrl,
    this.feedUrl,
    this.episodeCount = 0,
    this.episodes = const [],
  });

  factory Podcast.fromJson(Map<String, dynamic> json) => Podcast(
        id: (json['id'] ?? '').toString(),
        title: json['title'] ?? 'Unknown Podcast',
        author: json['author'] ?? json['publisher'],
        description: json['description'],
        thumbnailUrl: json['thumbnail'] ?? json['image'],
        feedUrl: json['feedUrl'] ?? json['feed_url'],
        episodeCount: json['episodeCount'] ?? json['total_episodes'] ?? 0,
        episodes: (json['episodes'] as List?)
                ?.map((e) => PodcastEpisode.fromJson(e))
                .toList() ??
            [],
      );

  Podcast copyWithEpisodes(List<PodcastEpisode> newEpisodes) {
    return Podcast(
      id: id,
      title: title,
      author: author,
      description: description,
      thumbnailUrl: thumbnailUrl,
      feedUrl: feedUrl,
      episodeCount: episodeCount,
      episodes: newEpisodes,
    );
  }

  String get authorDisplay => author ?? 'Unknown Author';
}
