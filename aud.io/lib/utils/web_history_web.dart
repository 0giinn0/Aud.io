import 'package:web/web.dart' as web;

/// Web implementation — uses the browser History API to replace the URL
/// without adding a history entry (used to strip OAuth callback params).
void replaceUrl(String url) {
  web.window.history.replaceState(null, '', url);
}
