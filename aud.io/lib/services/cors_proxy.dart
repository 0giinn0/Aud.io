import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Wraps URLs with public CORS proxies when running on web so the browser
/// allows cross-origin requests. On native (APK) the original URL is
/// returned unchanged — no CORS restrictions on mobile.
///
/// Different proxy strategies for different content types:
/// - **API calls** (small JSON): corsproxy.io → codetabs → allorigins
/// - **Images**: images.weserv.nl (dedicated image CDN, always CORS-safe)
/// - **Large content** (RSS feeds): allorigins /get (JSON-wrapped, always
///   sends CORS headers) → codetabs
class CorsProxy {
  CorsProxy._();

  // ── GET proxies for API calls (small JSON responses) ──
  static const _getProxies = [
    'https://corsproxy.io/?url={url}',
    'https://api.codetabs.com/v1/proxy/?quest={url}',
    'https://api.allorigins.win/get?url={url}',
  ];

  // ── POST proxies ──
  static const _postProxies = [
    'https://thingproxy.freeboard.io/fetch/{url}',
    'https://corsproxy.io/?url={url}',
  ];

  // ── Large content proxies (RSS feeds, big XML) ──
  // allorigins /get returns JSON {contents: "...", status: {...}} with
  // proper CORS headers — works even when /raw is blocked.
  static const _largeProxies = [
    'https://api.allorigins.win/get?url={url}',
    'https://api.codetabs.com/v1/proxy/?quest={url}',
    'https://corsproxy.io/?url={url}',
  ];

  /// Wrap an image URL for CORS-safe loading on web.
  /// Uses images.weserv.nl — a free image CDN/proxy that always sends
  /// CORS headers and handles redirects, HTTPS upgrades, and resizing.
  static String wrapImage(String url) {
    if (!kIsWeb) return url;
    // weserv expects the URL without the protocol scheme.
    final stripped = url.replaceFirst(RegExp(r'^https?://'), '');
    return 'https://images.weserv.nl/?url=$stripped';
  }

  /// Wrap a GET request URL for CORS-safe fetching on web.
  static String wrap(String url) {
    if (!kIsWeb) return url;
    return wrapGetN(url, 0) ?? url;
  }

  /// Wrap a GET URL with the nth proxy (0-indexed). Returns null if no
  /// more proxies are available.
  static String? wrapGetN(String url, int n) {
    if (!kIsWeb) return url;
    if (n >= _getProxies.length) return null;
    final encoded = Uri.encodeComponent(url);
    return _getProxies[n].replaceAll('{url}', encoded);
  }

  /// Wrap a POST URL with the nth proxy (0-indexed). Returns null if no
  /// more proxies are available.
  static String? wrapPostN(String url, int n) {
    if (!kIsWeb) return url;
    if (n >= _postProxies.length) return null;
    if (_postProxies[n].startsWith('https://corsproxy.io')) {
      return _postProxies[n].replaceAll('{url}', Uri.encodeComponent(url));
    }
    return _postProxies[n].replaceAll('{url}', url);
  }

  /// Wrap a large content URL (RSS feeds, big XML) with the nth proxy.
  static String? wrapLargeN(String url, int n) {
    if (!kIsWeb) return url;
    if (n >= _largeProxies.length) return null;
    final encoded = Uri.encodeComponent(url);
    return _largeProxies[n].replaceAll('{url}', encoded);
  }

  /// Fetch a URL through CORS proxies on web (tries each in order until
  /// one succeeds). On native, fetches directly.
  /// For small JSON API responses.
  static Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    if (!kIsWeb) {
      return http.get(Uri.parse(url), headers: headers);
    }
    for (var i = 0;; i++) {
      final proxied = wrapGetN(url, i);
      if (proxied == null) break;
      try {
        final resp = await http.get(Uri.parse(proxied), headers: headers)
            .timeout(const Duration(seconds: 12));
        if (resp.statusCode == 200) {
          // allorigins /get wraps content in JSON {contents: "..."}
          if (proxied.contains('allorigins.win/get')) {
            return _unwrapAllorigins(resp);
          }
          return resp;
        }
      } catch (_) {}
    }
    return http.Response('', 404);
  }

  /// Fetch large content (RSS feeds) through CORS proxies on web.
  /// Tries proxies that handle large responses properly.
  static Future<http.Response> getLarge(String url, {Map<String, String>? headers}) async {
    if (!kIsWeb) {
      return http.get(Uri.parse(url), headers: headers);
    }
    for (var i = 0;; i++) {
      final proxied = wrapLargeN(url, i);
      if (proxied == null) break;
      try {
        final resp = await http.get(Uri.parse(proxied), headers: headers)
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          // allorigins /get wraps content in JSON {contents: "..."}
          if (proxied.contains('allorigins.win/get')) {
            return _unwrapAllorigins(resp);
          }
          return resp;
        }
      } catch (_) {}
    }
    return http.Response('', 404);
  }

  /// POST to a URL through CORS proxies on web (tries each in order).
  static Future<http.Response> post(String url,
      {Map<String, String>? headers, String? body}) async {
    if (!kIsWeb) {
      return http.post(Uri.parse(url), headers: headers, body: body);
    }
    for (var i = 0;; i++) {
      final proxied = wrapPostN(url, i);
      if (proxied == null) break;
      try {
        final resp = await http.post(Uri.parse(proxied), headers: headers, body: body)
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) return resp;
      } catch (_) {}
    }
    return http.Response('', 403);
  }

  /// Unwrap an allorigins /get JSON response {contents: "...", status: {...}}.
  static http.Response _unwrapAllorigins(http.Response resp) {
    try {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final contents = data['contents'] as String? ?? '';
      return http.Response(contents, 200, headers: resp.headers);
    } catch (_) {
      return resp;
    }
  }

  /// Whether we're on web (and thus need proxy wrapping).
  static bool get isActive => kIsWeb;
}
