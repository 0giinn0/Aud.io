import 'package:flutter/foundation.dart';

/// Wraps URLs with a public CORS proxy when running on web so the browser
/// allows cross-origin requests. On native (APK) the original URL is
/// returned unchanged — no CORS restrictions on mobile.
///
/// Uses `api.allorigins.win` (free, no API key, no rate limit for
/// reasonable usage) as the primary proxy. It supports GET requests with
/// full response passthrough.
class CorsProxy {
  CorsProxy._();

  /// Wrap a GET request URL for CORS-safe fetching on web.
  /// On native, returns the URL unchanged.
  static String wrap(String url) {
    if (!kIsWeb) return url;
    return 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
  }

  /// Whether we're on web (and thus need proxy wrapping).
  static bool get isActive => kIsWeb;
}
