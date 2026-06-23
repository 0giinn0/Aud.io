import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/cors_proxy.dart';

/// Client-side SoundCloud integration.
///
/// Ports the logic that previously lived in the Node.js server so the APK
/// can search and play SoundCloud without any backend. The client_id is
/// scraped from soundcloud.com (residential IPs work, which is what mobile
/// devices use) with hardcoded fallbacks for web (where proxies may fail).
class SoundCloudService {
  SoundCloudService._();

  static const Duration _timeout = Duration(seconds: 12);
  static String? _cachedClientId;
  static DateTime? _clientIdFetchedAt;
  static const Duration _clientIdTtl = Duration(hours: 1);

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static String? get _envClientId =>
      const String.fromEnvironment('SOUNDCLOUD_CLIENT_ID').isEmpty
          ? null
          : const String.fromEnvironment('SOUNDCLOUD_CLIENT_ID');

  // Known public SoundCloud client_ids used by the SoundCloud web app.
  // These rotate periodically but having them as fallback means the web
  // app can still search even when scraping fails through CORS proxies.
  static const _fallbackClientIds = [
    'iZIs9mchLcE5dlOhHxyr6zS6gIu04WBm',
    'a3c56ed8e6b2c99b25958a86e602bd23',
    'J3ungbohLH8n7ojbidcRTNG77E2Fb69Y',
  ];

  static Future<bool> _isValidClientId(String id) async {
    try {
      final resp = await CorsProxy.get(
        'https://api-v2.soundcloud.com/search/tracks?q=test&client_id=$id&limit=1',
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 8));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Resolve a working SoundCloud client_id, caching the result for ~1h.
  static Future<String?> _getClientId() async {
    if (_cachedClientId != null &&
        _clientIdFetchedAt != null &&
        DateTime.now().difference(_clientIdFetchedAt!) < _clientIdTtl) {
      return _cachedClientId;
    }

    // 1. Env var wins (if set & valid).
    final envId = _envClientId;
    if (envId != null && await _isValidClientId(envId)) {
      _cachedClientId = envId;
      _clientIdFetchedAt = DateTime.now();
      return envId;
    }

    // 2. Try hardcoded fallback client_ids (fast, no scraping needed).
    for (final id in _fallbackClientIds) {
      if (await _isValidClientId(id)) {
        _cachedClientId = id;
        _clientIdFetchedAt = DateTime.now();
        debugPrint('aud.io: SoundCloud client_id from fallback list');
        return id;
      }
    }

    // 3. Scrape the public web client from soundcloud.com.
    try {
      final resp = await CorsProxy.get('https://soundcloud.com',
          headers: {'User-Agent': _userAgent}).timeout(_timeout);
      final html = resp.body;

      // Inline client_id references.
      final inlineMatches =
          RegExp(r'client_id:"([^"]+)"').allMatches(html).map((m) => m[1]!);
      for (final id in inlineMatches) {
        if (await _isValidClientId(id)) {
          _cachedClientId = id;
          _clientIdFetchedAt = DateTime.now();
          debugPrint('aud.io: SoundCloud client_id scraped inline');
          return id;
        }
      }

      // Fallback: scan each <script src=...> bundle for a client_id.
      final scriptUrls = RegExp(r'<script[^>]+src="([^"]+)"')
          .allMatches(html)
          .map((m) => m[1]!)
          .toList()
          .reversed;
      for (final url in scriptUrls) {
        try {
          final jsResp = await CorsProxy.get(url,
              headers: {'User-Agent': _userAgent}).timeout(const Duration(seconds: 6));
          final m = RegExp(r'client_id:"([^"]+)"').firstMatch(jsResp.body);
          if (m != null && await _isValidClientId(m[1]!)) {
            _cachedClientId = m[1]!;
            _clientIdFetchedAt = DateTime.now();
            debugPrint('aud.io: SoundCloud client_id scraped from script');
            return m[1];
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('aud.io: SoundCloud client_id scrape failed: $e');
    }

    _cachedClientId = null;
    return null;
  }

  /// Search SoundCloud tracks and return [Track]s ready for the player.
  static Future<List<Track>> search(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];
    final clientId = await _getClientId();
    if (clientId == null) {
      debugPrint('aud.io: SoundCloud search skipped — no client_id');
      return [];
    }
    try {
      final resp = await CorsProxy.get(
        'https://api-v2.soundcloud.com/search/tracks?q=${Uri.encodeQueryComponent(query)}&client_id=$clientId&limit=$limit&offset=0',
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      ).timeout(_timeout);
      if (resp.statusCode != 200) {
        if (resp.statusCode == 401) {
          _cachedClientId = null; // force refresh on next call
        }
        return [];
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final collection = (data['collection'] as List?) ?? [];
      return collection
          .map((t) {
            final track = t as Map<String, dynamic>;
            final user = (track['user'] as Map<String, dynamic>?) ?? {};
            final artwork = (track['artwork_url'] as String?) ?? '';
            return Track(
              id: 'sc_${track['id']}',
              title: (track['title'] as String?) ?? 'Unknown',
              artist: (user['username'] as String?) ?? 'Unknown',
              thumbnailUrl: artwork.replaceFirst('large', 't500x500'),
              duration: ((track['duration'] as num?) ?? 0).toInt() ~/ 1000,
              source: TrackSource.soundcloud,
            );
          })
          .toList();
    } catch (e) {
      debugPrint('aud.io: SoundCloud search error: $e');
      return [];
    }
  }

  /// Resolve a playable stream URL for a SoundCloud track id (`sc_<numeric>`).
  /// Returns a progressive MP3 URL when available, otherwise HLS.
  static Future<String?> resolveStreamUrl(String trackId) async {
    final clientId = await _getClientId();
    if (clientId == null) return null;
    final scId = trackId.replaceFirst('sc_', '');
    try {
      final trackResp = await CorsProxy.get(
        'https://api-v2.soundcloud.com/tracks/$scId?client_id=$clientId',
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      ).timeout(_timeout);
      if (trackResp.statusCode == 401) {
        _cachedClientId = null;
        return resolveStreamUrl(trackId);
      }
      if (trackResp.statusCode != 200) return null;
      final track = jsonDecode(trackResp.body) as Map<String, dynamic>;
      final transcodings =
          ((track['media'] as Map?)?['transcodings'] as List?) ?? [];
      if (transcodings.isEmpty) return null;

      Map<String, dynamic>? pick(List<dynamic> list, bool Function(Map) pred) {
        for (final t in list) {
          final m = t as Map<String, dynamic>;
          if (pred(m)) return m;
        }
        return null;
      }

      final progressive = pick(transcodings, (t) {
        final format = t['format'] as Map?;
        return format?['protocol'] == 'progressive' &&
            RegExp(r'mp3', caseSensitive: false)
                .hasMatch((format?['mime_type'] as String?) ?? '');
      });
      final mp3 = pick(transcodings, (t) {
        final format = t['format'] as Map?;
        return RegExp(r'mp3', caseSensitive: false)
            .hasMatch((format?['mime_type'] as String?) ?? '');
      });
      final chosen = progressive ?? mp3 ?? transcodings.first;
      final url = chosen['url'] as String?;
      if (url == null) return null;

      final resolveResp = await CorsProxy.get(
        '$url?client_id=$clientId',
        headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
      ).timeout(_timeout);
      if (resolveResp.statusCode != 200) return null;
      final resolved = jsonDecode(resolveResp.body) as Map<String, dynamic>;
      return resolved['url'] as String?;
    } catch (e) {
      debugPrint('aud.io: SoundCloud stream resolve error: $e');
      return null;
    }
  }
}
