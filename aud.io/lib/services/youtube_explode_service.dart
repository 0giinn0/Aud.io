import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:aud_io/core/models/track.dart';
import 'api_service.dart';

/// Wraps [YoutubeExplode] to extract direct YouTube audio stream URLs
/// from the InnerTube API on mobile (APK), falling back to the server
/// proxy on web where CORS blocks the YouTube API.
///
/// Usage:
/// ```dart
/// final url = await YouTubeExplodeService.getAudioUrl(videoId);
/// ```
///
/// Results are cached for 6 hours to avoid repeated InnerTube calls.
class YouTubeExplodeService {
  YouTubeExplodeService._();

  static final _log = Logger('YouTubeExplodeService');

  static YoutubeExplode? _yt;
  static final _cache = <String, _CacheEntry>{};
  static const _ttl = Duration(hours: 6);

  /// Returns a playable audio URL for [videoId].
  ///
  /// On **mobile** (APK): calls InnerTube via [YoutubeExplode] directly,
  /// picks the highest-bitrate audio-only stream.
  ///
  /// On **web**: delegates to the server proxy (YouTube API has no CORS
  /// headers), so the server's yt-dlp handles extraction.
  static Future<String?> getAudioUrl(String videoId) async {
    // Web — fall through to the server proxy (no CORS from YouTube).
    if (kIsWeb) {
      return ApiService.proxyAudioUrl(videoId, TrackSource.youtube);
    }

    // Mobile — use cached value if fresh.
    final cached = _cache[videoId];
    if (cached != null && cached.expires.isAfter(DateTime.now())) {
      _log.fine('Cache hit for $videoId');
      return cached.url;
    }

    try {
      _yt ??= YoutubeExplode();

      final manifest = await _yt!.videos.streams.getManifest(videoId);
      final audio = manifest.audioOnly;

      if (audio.isEmpty) {
        _log.warning('No audio-only streams for $videoId');
        return null;
      }

      // Pick highest bitrate audio stream.
      audio.sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
      final best = audio.first;
      final url = best.url.toString();

      _cache[videoId] = _CacheEntry(url, DateTime.now().add(_ttl));
      _log.fine('Resolved $videoId → $url');
      return url;
    } catch (e, s) {
      _log.severe('Failed to extract audio URL for $videoId', e, s);
      // Fallback: try the server proxy even on mobile.
      _log.warning('Falling back to server proxy for $videoId');
      return ApiService.proxyAudioUrl(videoId, TrackSource.youtube);
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
