import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/core/models/podcast.dart';

class ApiService {
  ApiService._();

  static String get baseUrl {
    const envUrl = String.fromEnvironment('BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) return 'https://aud-io.onrender.com';
    return 'http://10.0.2.2:3000';
  }

  static String proxyAudioUrl(String id, TrackSource source) {
    final sourceStr = source == TrackSource.soundcloud ? 'soundcloud' : 'youtube';
    return '$baseUrl/api/stream/$id/audio?source=$sourceStr';
  }

  static String proxyDirectUrl(String url) {
    return '$baseUrl/api/proxy?url=${Uri.encodeComponent(url)}';
  }

  static Future<String?> getStreamUrl(String id, TrackSource source) async {
    try {
      final url = proxyAudioUrl(id, source);
      final resp = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (resp.statusCode < 400) return url;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Track>> search(String query) async {
    if (query.isEmpty) return [];
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/search?q=${Uri.encodeQueryComponent(query)}&max=20'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results.map((r) => Track.fromApiJson(r as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Podcast API ──

  static Future<List<Podcast>> getTrendingPodcasts({int max = 20, String lang = 'en'}) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/podcasts/trending?max=$max&lang=$lang'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results.map((r) => Podcast.fromJson(r as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Podcast>> searchPodcasts(String query, {int maxResults = 10}) async {
    if (query.isEmpty) return [];
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/podcasts/search?q=${Uri.encodeQueryComponent(query)}&max=$maxResults'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      return results.map((r) => Podcast.fromJson(r as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<PodcastEpisode>> getEpisodesFromFeed(String feedUrl, {int max = 20}) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/podcasts/feed?url=${Uri.encodeQueryComponent(feedUrl)}&max=$max'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final episodes = data['episodes'] as List<dynamic>? ?? [];
      return episodes.map((e) => PodcastEpisode.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Podcast?> getPodcastDetails(String podcastId, {int maxEpisodes = 10}) async {
    try {
      final resp = await http
          .get(Uri.parse('$baseUrl/api/podcasts/podcast/$podcastId?episodes=$maxEpisodes'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      return Podcast.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
