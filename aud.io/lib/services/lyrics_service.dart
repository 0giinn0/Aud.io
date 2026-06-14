import 'dart:convert';
import 'package:http/http.dart' as http;

class LyricsLine {
  final Duration timestamp;
  final String text;

  LyricsLine({required this.timestamp, required this.text});
}

class LyricsResult {
  final String? plainText;
  final List<LyricsLine>? syncedLines;
  final bool isSynced;

  LyricsResult({this.plainText, this.syncedLines, required this.isSynced});
}

class LyricsService {
  LyricsService._();

  static const _baseUrl = 'https://lrclib.net/api';

  static Future<LyricsResult?> fetchLyrics(String title, String artist, {int? duration}) async {
    try {
      final uri = Uri.parse('$_baseUrl/get?artist_name=${Uri.encodeQueryComponent(artist)}&track_name=${Uri.encodeQueryComponent(title)}');
      final resp = await http.get(uri, headers: {'User-Agent': 'aud.io/1.0'}).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      final synced = data['syncedLyrics'] as String?;
      final plain = data['plainLyrics'] as String?;

      if (synced != null && synced.isNotEmpty) {
        return LyricsResult(
          syncedLines: _parseLrc(synced),
          isSynced: true,
        );
      }

      if (plain != null && plain.isNotEmpty) {
        return LyricsResult(plainText: plain, isSynced: false);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<LyricsResult?> fetchByVideoId(String videoId, {String? title, String? artist, int? duration}) async {
    try {
      final uri = Uri.parse('$_baseUrl/get?video_id=$videoId');
      final resp = await http.get(uri, headers: {'User-Agent': 'aud.io/1.0'}).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return title != null && artist != null
          ? fetchLyrics(title, artist, duration: duration)
          : null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final synced = data['syncedLyrics'] as String?;
      final plain = data['plainLyrics'] as String?;

      if (synced != null && synced.isNotEmpty) {
        return LyricsResult(
          syncedLines: _parseLrc(synced),
          isSynced: true,
        );
      }

      if (plain != null && plain.isNotEmpty) {
        return LyricsResult(plainText: plain, isSynced: false);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static List<LyricsLine> _parseLrc(String lrc) {
    final lines = <LyricsLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    for (final line in lrc.split('\n')) {
      final match = regex.firstMatch(line.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millis = match.group(3)!.padRight(3, '0').substring(0, 3);
        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: int.parse(millis),
        );
        final text = match.group(4)?.trim() ?? '';
        if (text.isNotEmpty) {
          lines.add(LyricsLine(timestamp: timestamp, text: text));
        }
      }
    }
    return lines;
  }
}
