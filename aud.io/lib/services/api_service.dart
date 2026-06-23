import 'package:http/http.dart' as http;
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/core/models/podcast.dart';
import 'package:aud_io/services/soundcloud_service.dart';
import 'package:aud_io/services/podcast_service.dart';

/// Network entry point for the Flutter app.
///
/// The APK is fully self-contained — there is no Node.js server to deploy.
/// YouTube search/stream is handled by `youtube_explode_dart` and
/// `dart_ytmusic_api`; SoundCloud and Podcasts are handled by
/// [SoundCloudService] and [PodcastService] respectively.
///
/// `baseUrl` is now only used by optional features (Spotify import) that
/// still need an OAuth token-exchange backend. Set `BASE_URL` via
/// `--dart-define=BASE_URL=...` at build time to enable them; otherwise
/// those features are disabled gracefully.
class ApiService {
  ApiService._();

  static String get baseUrl {
    const envUrl = String.fromEnvironment('BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return '';
  }

  static bool get hasServer => baseUrl.isNotEmpty;

  static String proxyAudioUrl(String id, TrackSource source) {
    final sourceStr = source == TrackSource.soundcloud ? 'soundcloud' : 'youtube';
    return '$baseUrl/api/stream/$id/audio?source=$sourceStr';
  }

  static String proxyDirectUrl(String url) {
    return '$baseUrl/api/proxy?url=${Uri.encodeComponent(url)}';
  }

  static String proxyImageUrl(String url) {
    return '$baseUrl/api/proxy-image?url=${Uri.encodeComponent(url)}';
  }

  /// Resolve a playable audio URL for [id] / [source] using client-side logic.
  /// Only falls back to the optional server proxy if `BASE_URL` is set.
  static Future<String?> getStreamUrl(String id, TrackSource source) async {
    if (source == TrackSource.soundcloud) {
      return SoundCloudService.resolveStreamUrl(id);
    }
    if (hasServer) {
      try {
        final url = proxyAudioUrl(id, source);
        final resp = await http.head(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode < 400) return url;
      } catch (_) {}
    }
    return null;
  }

  /// Search SoundCloud directly from the device.
  static Future<List<Track>> search(String query) async {
    if (query.isEmpty) return [];
    return SoundCloudService.search(query, limit: 20);
  }

  // ── Podcast API (direct, no server) ──

  static Future<List<Podcast>> getTrendingPodcasts(
      {int max = 20, String lang = 'en'}) async {
    return PodcastService.trending(max: max, lang: lang);
  }

  static Future<List<Podcast>> searchPodcasts(String query,
      {int maxResults = 10}) async {
    if (query.isEmpty) return [];
    return PodcastService.search(query, max: maxResults);
  }

  static Future<List<PodcastEpisode>> getEpisodesFromFeed(String feedUrl,
      {int max = 20}) async {
    return PodcastService.episodesFromFeed(feedUrl, max);
  }

  static Future<Podcast?> getPodcastDetails(String podcastId,
      {int maxEpisodes = 10}) async {
    return PodcastService.details(podcastId, maxEpisodes: maxEpisodes);
  }
}
