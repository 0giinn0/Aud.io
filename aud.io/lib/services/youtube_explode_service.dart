import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'cors_proxy.dart';

/// Resolves YouTube video IDs to playable audio stream URLs across all
/// platforms without requiring a backend server.
///
/// **Mobile (APK)**: uses [YoutubeExplode] (InnerTube via `dart:io`
/// HttpClient), falling back to a direct InnerTube API call if the
/// package-level extraction fails.
///
/// **Web**: uses a direct InnerTube API POST proxied through [CorsProxy]
/// and wraps the resulting googlevideo.com URL through a CORS-friendly
/// proxy so the browser can play the stream.
class YouTubeExplodeService {
  YouTubeExplodeService._();

  static final _log = Logger('YouTubeExplodeService');

  static YoutubeExplode? _yt;
  static final _cache = <String, _CacheEntry>{};
  static const _ttl = Duration(hours: 6);

  // InnerTube API constants
  static const String _innerTubeUrl =
      'https://www.youtube.com/youtubei/v1/player?key=AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w';
  static const Map<String, dynamic> _defaultContext = {
    'client': {
      'clientName': 'ANDROID',
      'clientVersion': '19.09.37',
      'androidSdkVersion': 30,
    },
  };

  /// Returns a playable audio URL for [videoId] on any platform.
  static Future<String?> getAudioUrl(String videoId) async {
    final cached = _cache[videoId];
    if (cached != null && cached.expires.isAfter(DateTime.now())) {
      _log.fine('Cache hit for $videoId');
      return cached.url;
    }

    final String? url;
    if (kIsWeb) {
      url = await _resolveWeb(videoId);
    } else {
      url = await _resolveNative(videoId);
    }

    if (url != null) {
      _cache[videoId] = _CacheEntry(url, DateTime.now().add(_ttl));
    }
    return url;
  }

  /// Mobile/desktop: try [YoutubeExplode] first, then direct InnerTube.
  static Future<String?> _resolveNative(String videoId) async {
    try {
      _yt ??= YoutubeExplode();
      final manifest = await _yt!.videos.streams.getManifest(videoId);
      final audio = manifest.audioOnly;
      if (audio.isNotEmpty) {
        audio.sort(
            (a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
        return audio.first.url.toString();
      }
      _log.warning('No audio-only streams for $videoId via package');
    } catch (e, s) {
      _log.warning('YoutubeExplode failed for $videoId', e, s);
    }
    // Fallback: direct InnerTube call via http package.
    return _callInnerTubeDirect(videoId);
  }

  /// Web: InnerTube API through CORS proxy, wrap googlevideo URL.
  static Future<String?> _resolveWeb(String videoId) async {
    final streamUrl = await _callInnerTubeProxy(videoId);
    if (streamUrl == null) return null;
    return CorsProxy.wrap(streamUrl);
  }

  /// Direct InnerTube API call using the http package (native only).
  static Future<String?> _callInnerTubeDirect(String videoId) async {
    try {
      final body = jsonEncode({
        'videoId': videoId,
        'context': _defaultContext,
      });
      final resp = await http.post(
        Uri.parse(_innerTubeUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        _log.warning('Direct InnerTube returned ${resp.statusCode}');
        return null;
      }
      return _extractStreamUrl(resp.body);
    } catch (e, s) {
      _log.severe('Direct InnerTube failed for $videoId', e, s);
      return null;
    }
  }

  /// InnerTube API call through CORS proxy (web).
  static Future<String?> _callInnerTubeProxy(String videoId) async {
    try {
      final body = jsonEncode({
        'videoId': videoId,
        'context': _defaultContext,
      });
      final resp = await CorsProxy.post(
        _innerTubeUrl,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (resp.statusCode != 200) {
        _log.warning('InnerTube proxy returned ${resp.statusCode}');
        return null;
      }
      return _extractStreamUrl(resp.body);
    } catch (e, s) {
      _log.severe('InnerTube proxy failed for $videoId', e, s);
      return null;
    }
  }

  /// Parse InnerTube player response JSON and return the highest-bitrate
  /// audio-only stream URL.
  static String? _extractStreamUrl(String jsonBody) {
    try {
      final data = jsonDecode(jsonBody) as Map<String, dynamic>;
      final streamingData = data['streamingData'] as Map<String, dynamic>?;
      if (streamingData == null) return null;

      final List<Map<String, dynamic>> allFormats = [];
      final fmtList = streamingData['formats'] as List<dynamic>?;
      if (fmtList != null) {
        allFormats.addAll(fmtList.cast<Map<String, dynamic>>());
      }
      final adaptiveList = streamingData['adaptiveFormats'] as List<dynamic>?;
      if (adaptiveList != null) {
        allFormats.addAll(adaptiveList.cast<Map<String, dynamic>>());
      }

      final audioFormats = allFormats.where((f) {
        final mime = (f['mimeType'] as String? ?? '').toLowerCase();
        return mime.startsWith('audio/') && f.containsKey('url');
      }).toList();

      if (audioFormats.isEmpty) return null;

      audioFormats.sort((a, b) {
        final abr = (a['bitrate'] as num?)?.toInt() ?? 0;
        final bbr = (b['bitrate'] as num?)?.toInt() ?? 0;
        return bbr.compareTo(abr);
      });

      return audioFormats.first['url'] as String;
    } catch (e) {
      _log.severe('Failed to parse InnerTube response', e);
      return null;
    }
  }

  /// Invalidates a cached entry (e.g. when a track fails to play).
  static void invalidate(String videoId) {
    _cache.remove(videoId);
  }

  /// Disposes the underlying HTTP client.
  static void dispose() {
    _yt?.close();
    _yt = null;
    _cache.clear();
  }
}

class _CacheEntry {
  final String url;
  final DateTime expires;
  _CacheEntry(this.url, this.expires);
}
