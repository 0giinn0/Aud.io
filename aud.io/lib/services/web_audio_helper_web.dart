// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> createAudioBlobUrl(Uint8List bytes, String filename) async {
  final ext = filename.split('.').last.toLowerCase();
  final mime = switch (ext) {
    'mp3' => 'audio/mpeg',
    'wav' => 'audio/wav',
    'm4a' => 'audio/mp4',
    'ogg' => 'audio/ogg',
    'flac' => 'audio/flac',
    _ => 'audio/mpeg',
  };
  final blob = html.Blob([bytes], mime);
  return html.Url.createObjectUrl(blob);
}
