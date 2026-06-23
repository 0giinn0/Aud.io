import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:aud_io/core/models/track.dart';
import 'api_service.dart';

class YouTubeMusicService {
  YouTubeMusicService._();
  static final _instance = YouTubeMusicService._();
  static YouTubeMusicService get instance => _instance;

  YTMusic? _ytmusic;
  bool _initialized = false;

  static Future<void> initialize() async {
    if (_instance._initialized) return;
    if (kIsWeb) {
      _instance._initialized = true;
      debugPrint('aud.io: YTMusic initialized (web: no client-side API)');
      return;
    }
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

    if (kIsWeb) {
      // Web has no client-side InnerTube access (CORS) and no server is
      // deployed by default. If BASE_URL is configured we can still proxy.
      if (ApiService.hasServer) {
        return _proxySearch('/api/ytmusic/search', query, limit);
      }
      return [];
    }

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

    if (kIsWeb) {
      if (ApiService.hasServer) {
        return _proxySearch('/api/ytmusic/videos', query, limit);
      }
      return [];
    }

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

  static Future<List<Track>> _proxySearch(String path, String query, int limit) async {
    try {
      final resp = await http
          .post(
            Uri.parse('${ApiService.baseUrl}$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'query': query, 'limit': limit}),
          )
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((r) => Track(
                id: r['videoId'] ?? '',
                title: r['title'] ?? '',
                artist: r['artist'] ?? 'Unknown',
                thumbnailUrl: r['thumbnailUrl'],
                duration: r['duration'] ?? 0,
                source: TrackSource.youtube,
              ))
          .toList();
    } catch (e) {
      debugPrint('aud.io: YTMusic proxy search error: $e');
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
