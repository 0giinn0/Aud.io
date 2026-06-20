// Web implementation of file download
import 'package:web/web.dart';

void triggerDownload(String url, String filename) {
  final anchor = HTMLAnchorElement()
    ..href = url
    ..target = '_blank'
    ..download = filename;
  anchor.click();
  anchor.remove();
}
