import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/core/models/podcast.dart';

class ApiService {
  // Override at build time: flutter build apk --dart-define=BASE_URL=https://your-app.onrender.com
  static const String _envBaseUrl = String.fromEnvironment('BASE_URL');

  static String get _baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    // Android emulator reaches the host machine via 10.0.2.2, not localhost.
    // Physical devices need --dart-define=BASE_URL=http://<your-lan-ip>:3001.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3001';
    }
    return 'http://localhost:3001';
  }

  static String get baseUrl => _baseUrl;

  static String _sourceName(TrackSource source) {
    switch (source) {
      case TrackSource.soundcloud:
        return 'soundcloud';
      case TrackSource.fma:
        return 'fma';
      default:
        return 'youtube';
    }
  }

  /// Stable URL that streams audio bytes through the server proxy.
  /// Required for YouTube: extracted googlevideo URLs are IP-bound to the
  /// server, so devices must stream through it.
  static String proxyAudioUrl(String id, TrackSource source) {
    return '$_baseUrl/api/stream/${Uri.encodeComponent(id)}/audio?source=${_sourceName(source)}';
  }

  /// Proxy an arbitrary http(s) audio URL (e.g. podcast episodes) through the
  /// server so the browser gets CORS headers and Range support.
  static String proxyDirectUrl(String url) {
    return '$_baseUrl/api/proxy?url=${Uri.encodeQueryComponent(url)}';
  }

  static Future<List<Track>> search(String query, {int maxResults = 20}) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/search').replace(queryParameters: {
        'q': query,
        'max': maxResults.toString(),
      });
      debugPrint('aud.io API: GET $uri');

      final client = http.Client();
      final request = http.Request('GET', uri);
      final streamed = await client.send(request).timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);

      debugPrint('aud.io API: response ${response.statusCode} ${response.body.length} chars');

      if (response.statusCode != 200) {
        debugPrint('aud.io API: search error ${response.statusCode}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List? ?? [];
      debugPrint('aud.io API: parsed ${results.length} results');

      return results.map((r) {
        final item = r as Map<String, dynamic>;
        final source = item['source'] as String? ?? 'youtube';

        // Map source string to TrackSource
        TrackSource trackSource;
        switch (source) {
          case 'soundcloud':
            trackSource = TrackSource.soundcloud;
            break;
          case 'fma':
            trackSource = TrackSource.fma;
            break;
          default:
            trackSource = TrackSource.youtube;
        }

        return Track(
          id: item['id'] as String? ?? item['videoId'] as String? ?? item['trackId'] as String? ?? '',
          title: item['title'] as String? ?? 'Unknown',
          artist: item['artist'] as String? ?? item['author'] as String? ?? 'Unknown Artist',
          album: item['album'] as String?,
          thumbnailUrl: item['thumbnail'] as String?,
          audioUrl: item['audioUrl'] as String?,
          duration: item['duration'] as int? ?? 0,
          source: trackSource,
          license: item['license'] as String?,
          artistUrl: item['artistUrl'] as String?,
        );
      }).toList();
    } catch (e, st) {
      debugPrint('aud.io API: search failed: $e\n$st');
      return [];
    }
  }

  static Future<String?> getStreamUrl(String id, TrackSource source) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/stream/$id').replace(queryParameters: {
        'source': source == TrackSource.soundcloud
            ? 'soundcloud'
            : source == TrackSource.fma
                ? 'fma'
                : 'youtube',
      });
      debugPrint('aud.io API: GET $uri');

      final client = http.Client();
      final request = http.Request('GET', uri);
      final streamed = await client.send(request).timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);

      debugPrint('aud.io API: stream response ${response.statusCode}');

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['url'] as String?;
    } catch (e, st) {
      debugPrint('aud.io API: stream URL error: $e\n$st');
      return null;
    }
  }

  static Future<Track?> getFMADetails(String id) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/fma/details/$id');
      debugPrint('aud.io API: GET $uri');

      final client = http.Client();
      final request = http.Request('GET', uri);
      final streamed = await client.send(request).timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Track.fromJson(data);
    } catch (e, st) {
      debugPrint('aud.io API: FMA details error: $e\n$st');
      return null;
    }
  }

  // ===== PODCAST METHODS (Podcast Index) =====

  static Future<List<Podcast>> searchPodcasts(String query, {int maxResults = 10}) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/podcasts/search').replace(queryParameters: {
        'q': query,
        'max': maxResults.toString(),
      });
      debugPrint('aud.io API: GET $uri');

      final client = http.Client();
      final request = http.Request('GET', uri);
      final streamed = await client.send(request).timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List? ?? [];

      return results.map((r) => Podcast.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e, st) {
      debugPrint('aud.io API: podcast search failed: $e\n$st');
      return [];
    }
  }

  static Future<List<Podcast>> getTrendingPodcasts({int maxResults = 20}) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/podcasts/trending').replace(queryParameters: {
        'max': maxResults.toString(),
      });
      debugPrint('aud.io API: GET $uri');

      final client = http.Client();
      final request = http.Request('GET', uri);
      final streamed = await client.send(request).timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List? ?? [];

      return results.map((r) => Podcast.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e, st) {
      debugPrint('aud.io API: trending podcasts error: $e\n$st');
      return [];
    }
  }

  static Future<Podcast?> getPodcastDetails(dynamic feedId, {int episodes = 10}) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/podcasts/podcast/$feedId').replace(queryParameters: {
        'episodes': episodes.toString(),
      });
      debugPrint('aud.io API: GET $uri');

      final client = http.Client();
      final request = http.Request('GET', uri);
      final streamed = await client.send(request).timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Podcast.fromJson(data);
    } catch (e, st) {
      debugPrint('aud.io API: podcast details error: $e\n$st');
      return null;
    }
  }

  static Future<List<PodcastEpisode>> getEpisodesFromFeed(String feedUrl, {int max = 20}) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/podcasts/feed').replace(queryParameters: {
        'url': feedUrl,
        'max': max.toString(),
      });
      debugPrint('aud.io API: GET $uri');

      final client = http.Client();
      final request = http.Request('GET', uri);
      final streamed = await client.send(request).timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['episodes'] as List? ?? [];

      return results.map((r) => PodcastEpisode.fromJson(r as Map<String, dynamic>)).toList();
    } catch (e, st) {
      debugPrint('aud.io API: feed episodes error: $e\n$st');
      return [];
    }
  }
}
