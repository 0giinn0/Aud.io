// Web implementation of file download
import 'dart:html';

void triggerDownload(String url, String filename) {
  final anchor = AnchorElement(href: url)
    ..target = '_blank'
    ..download = filename;
  anchor.click();
  anchor.remove();
}
