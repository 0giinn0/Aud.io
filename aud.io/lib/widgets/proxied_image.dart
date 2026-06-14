import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Wraps [Image.network] with a proxy that provides CORS headers and
/// upgrades HTTP → HTTPS, fixing common web-blocked image issues.
///
/// On mobile (APK) the original URL is used directly (no CORS issues).
class ProxiedImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final BorderRadius? borderRadius;

  const ProxiedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.borderRadius,
  });

  String? get _proxyUrl {
    if (url == null || url!.isEmpty) return null;
    // On mobile (APK) use original URL — no CORS issues
    if (!kIsWeb) return url;
    // On web, proxy through the Worker on the same domain.
    return '/api/proxy-image?url=${Uri.encodeQueryComponent(url!)}';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _proxyUrl;
    if (imageUrl == null) {
      return _placeholder();
    }
    final image = Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          errorBuilder?.call(context, error, stackTrace) ?? _placeholder(),
    );
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.black26,
      child: const Center(child: Icon(Icons.broken_image, color: Colors.white38)),
    );
  }
}
