import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:aud_io/core/models/podcast.dart';
import 'package:aud_io/services/cors_proxy.dart';

/// Client-side Podcast Index API integration.
///
/// Replaces the Node.js server proxy so the APK can search, browse
/// trending, and play podcasts with no backend.
///
/// - `/search` (Apple-replacement) endpoint is free; no auth needed.
/// - `/api/1.0/...` endpoints require an API key + secret, which can be
///   supplied via the `PODCAST_INDEX_API_KEY` / `PODCAST_INDEX_API_SECRET`
///   env vars (baked into the APK at build time via --dart-define).
///   Get a free key at https://podcastindex.org/.
class PodcastService {
  PodcastService._();

  static const Duration _timeout = Duration(seconds: 12);
  static const String _userAgent = 'aud.io/1.0';

  static const String _freeSearchBase = 'https://api.podcastindex.org/search';
  static const String _authBase = 'https://api.podcastindex.org/api/1.0';

  static String? get _apiKey =>
      const String.fromEnvironment('PODCAST_INDEX_API_KEY').isEmpty
          ? null
          : const String.fromEnvironment('PODCAST_INDEX_API_KEY');
  static String? get _apiSecret =>
      const String.fromEnvironment('PODCAST_INDEX_API_SECRET').isEmpty
          ? null
          : const String.fromEnvironment('PODCAST_INDEX_API_SECRET');

  static Map<String, String>? _authHeaders() {
    if (_apiKey == null || _apiSecret == null) return null;
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final raw = '$_apiKey$_apiSecret$timestamp';
    final hash = _sha1Hex(utf8.encode(raw));
    return {
      'User-Agent': _userAgent,
      'X-Auth-Key': _apiKey!,
      'X-Auth-Date': timestamp,
      'Authorization': hash,
    };
  }

  /// Search podcasts (free, no auth).
  static Future<List<Podcast>> search(String query, {int max = 10}) async {
    if (query.isEmpty) return [];
    try {
      final resp = await CorsProxy.get(
        '$_freeSearchBase?term=${Uri.encodeQueryComponent(query)}&entity=podcast',
        headers: {'User-Agent': _userAgent},
      ).timeout(_timeout);
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = (data['results'] as List?) ?? [];
      return results.take(max).map((r) {
        final j = r as Map<String, dynamic>;
        return Podcast(
          id: (j['collectionId'] ?? j['id'] ?? '').toString(),
          title: (j['collectionName'] ?? j['trackName'] ?? 'Unknown') as String,
          author: (j['artistName'] ?? 'Unknown') as String?,
          description: '',
          thumbnailUrl: (j['artworkUrl600'] ?? j['artworkUrl100'] ?? '') as String?,
          feedUrl: (j['feedUrl'] ?? '') as String?,
          episodeCount: (j['trackCount'] ?? 0) as int,
        );
      }).toList();
    } catch (e) {
      debugPrint('aud.io: podcast search error: $e');
      return [];
    }
  }

  /// Trending podcasts (requires API key).
  static Future<List<Podcast>> trending({int max = 20, String lang = 'en'}) async {
    final headers = _authHeaders();
    if (headers == null) {
      debugPrint('aud.io: podcast trending skipped — no API key');
      return [];
    }
    try {
      final resp = await CorsProxy.get(
        '$_authBase/podcasts/trending?max=$max&lang=$lang',
        headers: headers,
      ).timeout(_timeout);
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final feeds = (data['feeds'] as List?) ?? [];
      return feeds.map((f) {
        final j = f as Map<String, dynamic>;
        return Podcast(
          id: (j['id'] ?? '').toString(),
          title: (j['title'] ?? 'Unknown') as String,
          author: (j['author'] ?? j['owner'] ?? 'Unknown') as String?,
          description: (j['description'] ?? '') as String?,
          thumbnailUrl: (j['image'] ?? j['artwork'] ?? '') as String?,
          feedUrl: (j['url'] ?? '') as String?,
          episodeCount: (j['episodeCount'] ?? 0) as int,
        );
      }).toList();
    } catch (e) {
      debugPrint('aud.io: podcast trending error: $e');
      return [];
    }
  }

  /// Podcast details + recent episodes (requires API key).
  static Future<Podcast?> details(String feedId, {int maxEpisodes = 10}) async {
    final headers = _authHeaders();
    if (headers == null) return null;
    try {
      final podResp = await CorsProxy.get(
        '$_authBase/podcasts/byfeedid?id=$feedId',
        headers: headers,
      ).timeout(_timeout);
      if (podResp.statusCode != 200) return null;
      final podData = jsonDecode(podResp.body) as Map<String, dynamic>;
      final feed = podData['feed'] as Map<String, dynamic>?;
      if (feed == null) return null;

      final epResp = await CorsProxy.get(
        '$_authBase/episodes/byfeedid?id=$feedId&max=$maxEpisodes',
        headers: headers,
      ).timeout(_timeout);
      List<PodcastEpisode> episodes = [];
      if (epResp.statusCode == 200) {
        final epData = jsonDecode(epResp.body) as Map<String, dynamic>;
        final items = (epData['items'] as List?) ?? [];
        episodes = items.map((e) {
          final j = e as Map<String, dynamic>;
          return PodcastEpisode(
            id: (j['id'] ?? '').toString(),
            title: (j['title'] ?? 'Unknown') as String,
            description: (j['description'] ?? '') as String?,
            audioUrl: (j['enclosureUrl'] ?? '') as String?,
            duration: ((j['duration'] ?? 0) as num).toInt(),
            publishDate: ((j['datePublished'] ?? 0) as num).toInt(),
            thumbnailUrl: (j['image'] ?? feed['image'] ?? '') as String?,
            podcastId: feedId,
            podcastTitle: (feed['title'] ?? '') as String?,
            podcastAuthor: (feed['author'] ?? '') as String?,
          );
        }).toList();
      }

      return Podcast(
        id: (feed['id'] ?? '').toString(),
        title: (feed['title'] ?? 'Unknown') as String,
        author: (feed['author'] ?? feed['owner'] ?? 'Unknown') as String?,
        description: (feed['description'] ?? '') as String?,
        thumbnailUrl: (feed['image'] ?? feed['artwork'] ?? '') as String?,
        feedUrl: (feed['url'] ?? '') as String?,
        episodeCount: (feed['episodeCount'] ?? 0) as int,
        episodes: episodes,
      );
    } catch (e) {
      debugPrint('aud.io: podcast details error: $e');
      return null;
    }
  }

  /// Parse an RSS feed for episodes (no auth required).
  /// Uses getLarge on web — RSS feeds can be big and need proxies that
  /// handle large responses (allorigins /get wraps in JSON with CORS).
  static Future<List<PodcastEpisode>> episodesFromFeed(
      String feedUrl, int max) async {
    try {
      final resp = await CorsProxy.getLarge(feedUrl,
          headers: {'User-Agent': _userAgent}).timeout(_timeout);
      if (resp.statusCode != 200) return [];
      return _parseRss(resp.body, max);
    } catch (e) {
      debugPrint('aud.io: podcast feed parse error: $e');
      return [];
    }
  }

  static List<PodcastEpisode> _parseRss(String xml, int max) {
    final episodes = <PodcastEpisode>[];
    final channelMatch =
        RegExp(r'<channel>([\s\S]*?)</channel>', caseSensitive: false)
            .firstMatch(xml);
    if (channelMatch == null) return episodes;
    final channel = channelMatch.group(1)!;
    final channelTitle = _readTag(channel, 'title') ?? 'Podcast';
    final channelAuthor = _readItunesTag(channel, 'author') ??
        _readTag(channel, 'author') ??
        'Unknown';

    final itemRegex = RegExp(r'<item>([\s\S]*?)</item>', caseSensitive: false);
    for (final match in itemRegex.allMatches(xml)) {
      if (episodes.length >= max) break;
      final item = match.group(1)!;
      final title = _readTag(item, 'title') ?? 'Unknown Episode';
      final guid = _readTag(item, 'guid') ?? DateTime.now().toString();
      final description =
          _stripHtml(_readTag(item, 'description') ?? '');
      final pubDate = _parsePubDate(_readTag(item, 'pubDate'));
      final duration = _parseDuration(_readItunesTag(item, 'duration') ?? '');
      final audioUrl = _readEnclosureUrl(item);
      final thumb = _readItunesImage(item);
      episodes.add(PodcastEpisode(
        id: guid,
        title: title,
        description: description,
        audioUrl: audioUrl,
        duration: duration,
        publishDate: pubDate,
        thumbnailUrl: thumb,
        podcastTitle: channelTitle,
        podcastAuthor: channelAuthor,
      ));
    }
    return episodes;
  }

  static String? _readTag(String xml, String tag) {
    final m = RegExp('<$tag[^>]*>([\\s\\S]*?)</$tag>', caseSensitive: false)
        .firstMatch(xml);
    return m?.group(1)?.trim();
  }

  static String? _readItunesTag(String xml, String tag) {
    return _readTag(xml, 'itunes:$tag');
  }

  static String? _readItunesImage(String xml) {
    final m = RegExp(r'<itunes:image[^>]*href="([^"]+)"',
            caseSensitive: false)
        .firstMatch(xml);
    return m?.group(1);
  }

  static String? _readEnclosureUrl(String xml) {
    final m =
        RegExp(r'<enclosure[^>]*url="([^"]+)"', caseSensitive: false)
            .firstMatch(xml);
    return m?.group(1);
  }

  static String _stripHtml(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  static int _parsePubDate(String? s) {
    if (s == null || s.isEmpty) return 0;
    return DateTime.tryParse(s)?.millisecondsSinceEpoch ?? 0;
  }

  static int _parseDuration(String s) {
    if (s.isEmpty) return 0;
    if (int.tryParse(s) != null) return int.parse(s);
    final parts = s.split(':').map(int.tryParse).toList();
    if (parts.any((p) => p == null)) return 0;
    if (parts.length == 3) return parts[0]! * 3600 + parts[1]! * 60 + parts[2]!;
    if (parts.length == 2) return parts[0]! * 60 + parts[1]!;
    return parts.firstOrNull ?? 0;
  }

  /// Minimal SHA-1 implementation (RFC 3174) for Podcast Index auth.
  /// Avoids requiring an external crypto package in the APK.
  static String _sha1Hex(List<int> bytes) {
    final msg = List<int>.from(bytes);
    final ml = msg.length * 8;
    msg.add(0x80);
    while (msg.length % 64 != 56) {
      msg.add(0);
    }
    for (int i = 7; i >= 0; i--) {
      msg.add((ml >> (i * 8)) & 0xff);
    }

    int h0 = 0x67452301, h1 = 0xEFCDAB89, h2 = 0x98BADCFE, h3 = 0x10325476,
        h4 = 0xC3D2E1F0;

    for (int chunk = 0; chunk < msg.length; chunk += 64) {
      final w = List<int>.filled(80, 0);
      for (int i = 0; i < 16; i++) {
        w[i] = (msg[chunk + i * 4] << 24) |
            (msg[chunk + i * 4 + 1] << 16) |
            (msg[chunk + i * 4 + 2] << 8) |
            (msg[chunk + i * 4 + 3]);
      }
      for (int i = 16; i < 80; i++) {
        final t = _rotl(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
        w[i] = t;
      }

      int a = h0, b = h1, c = h2, d = h3, e = h4;
      for (int i = 0; i < 80; i++) {
        int f, k;
        if (i < 20) {
          f = (b & c) | ((~b) & d);
          k = 0x5A827999;
        } else if (i < 40) {
          f = b ^ c ^ d;
          k = 0x6ED9EBA1;
        } else if (i < 60) {
          f = (b & c) | (b & d) | (c & d);
          k = 0x8F1BBCDC;
        } else {
          f = b ^ c ^ d;
          k = 0xCA62C1D6;
        }
        final temp = (_rotl(a, 5) + f + e + k + w[i]) & 0xFFFFFFFF;
        e = d;
        d = c;
        c = _rotl(b, 30);
        b = a;
        a = temp;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
    }

    final hex = [h0, h1, h2, h3, h4]
        .map((v) => v.toRadixString(16).padLeft(8, '0'))
        .join();
    return hex;
  }

  static int _rotl(int v, int n) => ((v << n) | (v >>> (32 - n))) & 0xFFFFFFFF;
}
