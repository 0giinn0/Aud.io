import 'package:flutter/foundation.dart';
import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:aud_io/core/models/track.dart';

class YouTubeMusicService {
  YouTubeMusicService._();
  static final _instance = YouTubeMusicService._();
  static YouTubeMusicService get instance => _instance;

  YTMusic? _ytmusic;
  bool _initialized = false;

  static Future<void> initialize() async {
    if (_instance._initialized) return;
    try {
      _instance._ytmusic = YTMusic();
      await _instance._ytmusic!.initialize();
      _instance._initialized = true;
      debugPrint('aud.io: YTMusic initialized');
    } catch (e, s) {
      debugPrint('aud.io: YTMusic init failed: $e\n$s');
    }
  }

  static bool get isAvailable => _instance._initialized;

  static Future<List<Track>> searchSongs(String query, {int limit = 20}) async {
    if (!_instance._initialized) await initialize();
    if (_instance._ytmusic == null) return [];

    try {
      final results = await _instance._ytmusic!.searchSongs(query);
      final tracks = <Track>[];
      for (final r in results.take(limit)) {
        final thumb = r.thumbnails.isNotEmpty ? r.thumbnails.first.url : null;
        tracks.add(Track(
          id: r.videoId,
          title: r.name,
          artist: r.artist.name,
          thumbnailUrl: thumb,
          duration: r.duration ?? 0,
          source: TrackSource.youtube,
        ));
      }
      return tracks;
    } catch (e) {
      debugPrint('aud.io: YTMusic search error: $e');
      return [];
    }
  }

  static Future<List<Track>> searchVideos(String query, {int limit = 20}) async {
    if (!_instance._initialized) await initialize();
    if (_instance._ytmusic == null) return [];

    try {
      final results = await _instance._ytmusic!.searchVideos(query);
      final tracks = <Track>[];
      for (final r in results.take(limit)) {
        final thumb = r.thumbnails.isNotEmpty ? r.thumbnails.first.url : null;
        tracks.add(Track(
          id: r.videoId,
          title: r.name,
          artist: r.artist.name,
          thumbnailUrl: thumb,
          duration: r.duration ?? 0,
          source: TrackSource.youtube,
        ));
      }
      return tracks;
    } catch (e) {
      debugPrint('aud.io: YTMusic videos error: $e');
      return [];
    }
  }

  static Future<List<Track>> searchAll(String query, {int limit = 20}) async {
    final songs = await searchSongs(query, limit: limit);
    if (songs.length >= limit) return songs.take(limit).toList();
    final videos = await searchVideos(query, limit: limit - songs.length);
    return [...songs, ...videos].take(limit).toList();
  }
}
