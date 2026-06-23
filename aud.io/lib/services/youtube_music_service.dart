import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dart_ytmusic_api/yt_music.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/api_service.dart';
import 'package:aud_io/services/cors_proxy.dart';

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
      // Web has no client-side InnerTube access (CORS). If a dedicated
      // server is configured, use it. Otherwise, try the public CORS
      // proxy approach (POST through a CORS-bypassing endpoint).
      if (ApiService.hasServer) {
        return _proxySearch('/api/ytmusic/search', query, limit);
      }
      return _corsProxySearch(query, limit);
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
      return _corsProxySearch(query, limit);
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

  /// Search YouTube Music on web by POSTing to the InnerTube API through
  /// public CORS proxies. Tries multiple proxies until one succeeds.
  static Future<List<Track>> _corsProxySearch(String query, int limit) async {
    try {
      const innerTubeKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';
      final innerTubeUrl =
          'https://music.youtube.com/youtubei/v1/search?alt=json&key=$innerTubeKey';

      final context = {
        'context': {
          'client': {
            'hl': 'en',
            'gl': 'US',
            'clientName': 'WEB_REMIX',
            'clientVersion': '1.20240101.00.00',
          },
        },
        'query': query,
        'params': 'EgWKAQIIAWoKEAMQBBAJEAoQBQ%3D%3D',
      };

      final resp = await CorsProxy.post(
        innerTubeUrl,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Origin': 'https://music.youtube.com',
          'Referer': 'https://music.youtube.com/',
        },
        body: jsonEncode(context),
      );

      if (resp.statusCode != 200) {
        debugPrint('aud.io: YTMusic CORS proxy search HTTP ${resp.statusCode}');
        return [];
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final sections = (body['contents']?['tabbedSearchResultsRenderer']?['tabs']
              as List?)
              ?.firstOrNull?['tabRenderer']?['content']?['sectionListRenderer']
              ?['contents'] as List? ??
          [];
      final items = <Track>[];
      for (final section in sections) {
        final s = section as Map<String, dynamic>;
        final contents = (s['musicShelfRenderer']?['contents'] ??
                s['musicPlaylistShelfRenderer']?['contents']) as List? ??
            [];
        for (final c in contents) {
          final song = (c as Map<String, dynamic>)['musicResponsiveListItemRenderer']
              as Map<String, dynamic>?;
          if (song == null) continue;
          final title = (song['flexColumns'] as List?)
                  ?.firstOrNull?['musicResponsiveListItemFlexColumnRenderer']
              ?['text']?['runs']?['first']?['text'] ??
              '';
          final artist = ((song['flexColumns'] as List?)?.elementAt(1)
                      ?['musicResponsiveListItemFlexColumnRenderer']?['text']
                  ?['runs'] as List?)
                  ?.firstOrNull?['text'] ??
              'Unknown';
          final videoId = song['overlay']?['musicItemThumbnailOverlayRenderer']
                  ?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']
                  ?['watchEndpoint']?['videoId'] ??
              '';
          final durationText = ((song['flexColumns'] as List?)?.elementAt(2)
                  ?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs']
              as List?)
              ?.firstOrNull?['text'] ??
              '';
          final thumbnails = song['thumbnail']?['musicThumbnailThumbnailRenderer']
                  ?['thumbnails'] as List? ??
              [];
          if (title.isEmpty || videoId.isEmpty) continue;
          int duration = 0;
          if (durationText.isNotEmpty) {
            final parts = durationText.split(':').map(int.tryParse).toList();
            if (parts.length == 2) {
              duration = parts[0]! * 60 + parts[1]!;
            } else if (parts.length == 3) {
              duration = parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
            }
          }
          items.add(Track(
            id: videoId,
            title: title,
            artist: artist,
            thumbnailUrl: _extractThumbUrl(thumbnails),
            duration: duration,
            source: TrackSource.youtube,
          ));
          if (items.length >= limit) break;
        }
        if (items.length >= limit) break;
      }
      return items;
    } catch (e) {
      debugPrint('aud.io: YTMusic CORS proxy search error: $e');
      return [];
    }
  }

  static Future<List<Track>> searchAll(String query, {int limit = 20}) async {
    final songs = await searchSongs(query, limit: limit);
    if (songs.length >= limit) return songs.take(limit).toList();
    final videos = await searchVideos(query, limit: limit - songs.length);
    return [...songs, ...videos].take(limit).toList();
  }

  static String? _extractThumbUrl(List? thumbnails) {
    if (thumbnails == null || thumbnails.isEmpty) return null;
    final first = thumbnails.first as Map<String, dynamic>?;
    return first?['url'] as String?;
  }
}
