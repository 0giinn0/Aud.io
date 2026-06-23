/// Platform-agnostic URL-history shim.
///
/// On web, delegates to `package:web` to replace the browser URL.
/// On native platforms, this is a no-op (there's no browser history to
/// clear). The conditional import picks the right implementation at
/// compile time so `package:web` is never compiled for Android/iOS.
library;

export 'web_history_stub.dart'
    if (dart.library.js_interop) 'web_history_web.dart';
