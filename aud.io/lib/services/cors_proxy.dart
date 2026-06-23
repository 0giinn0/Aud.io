import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Wraps URLs with public CORS proxies when running on web so the browser
/// allows cross-origin requests. On native (APK) the original URL is
/// returned unchanged — no CORS restrictions on mobile.
///
/// Multiple proxies are tried in order — if one is down or blocks the
/// request, the next is used.
class CorsProxy {
  CorsProxy._();

  // GET proxy templates — {url} is replaced with the encoded target URL.
  static const _getProxies = [
    'https://corsproxy.io/?url={url}',
    'https://api.codetabs.com/v1/proxy/?quest={url}',
    'https://api.allorigins.win/raw?url={url}',
  ];

  // POST proxy templates — {url} is replaced with the raw target URL.
  static const _postProxies = [
    'https://thingproxy.freeboard.io/fetch/{url}',
    'https://corsproxy.io/?url={url}',
  ];

  /// Wrap a GET request URL for CORS-safe fetching on web.
  /// Uses the first proxy in the list. For multi-proxy fallback, use
  /// [CorsProxy.get] instead.
  static String wrap(String url) {
    if (!kIsWeb) return url;
    final proxied = wrapGetN(url, 0);
    return proxied ?? url;
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
    // thingproxy wants the raw URL, corsproxy wants it encoded.
    if (_postProxies[n].startsWith('https://corsproxy.io')) {
      return _postProxies[n].replaceAll('{url}', Uri.encodeComponent(url));
    }
    return _postProxies[n].replaceAll('{url}', url);
  }

  /// Fetch a URL through CORS proxies on web (tries each in order until
  /// one succeeds). On native, fetches directly.
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
        if (resp.statusCode == 200) return resp;
      } catch (_) {}
    }
    // Return a dummy 404 if all proxies failed.
    return http.Response('', 404);
  }

  /// POST to a URL through CORS proxies on web (tries each in order).
  /// On native, posts directly.
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

  /// Whether we're on web (and thus need proxy wrapping).
  static bool get isActive => kIsWeb;
}
