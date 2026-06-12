import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generates and exports a PDF crediting every third-party API, data source
/// and open-source library aud.io relies on. Triggered from Settings.
class AccreditationService {
  static const _red = PdfColor.fromInt(0xFFE8432A);
  static const _ink = PdfColor.fromInt(0xFF14120F);
  static const _muted = PdfColor.fromInt(0xFF6B6660);

  static final List<_Credit> _sources = [
    _Credit(
      'YouTube',
      'Music & video metadata and audio streams',
      'Content © respective owners. Accessed via the YouTube platform; '
          'playback is provided for personal use. aud.io is not affiliated with '
          'or endorsed by YouTube / Google LLC.',
    ),
    _Credit(
      'SoundCloud',
      'Track search and audio streams (api-v2.soundcloud.com)',
      'Content © respective artists and rights holders. aud.io is not affiliated '
          'with or endorsed by SoundCloud Global Limited & Co. KG.',
    ),
    _Credit(
      'Free Music Archive / Internet Archive',
      'Creative-Commons licensed music (archive.org)',
      'Tracks are distributed under their individual Creative Commons licenses; '
          'attribution belongs to the original artists.',
    ),
    _Credit(
      'Podcast Index',
      'Podcast search, trending and episode feeds (podcastindex.org)',
      'Podcast metadata provided by the Podcast Index open directory. '
          'Episodes © their respective publishers.',
    ),
    _Credit(
      'Apple iTunes Search API',
      'Podcast and artwork lookup',
      'Metadata provided by Apple Inc. aud.io is not affiliated with or '
          'endorsed by Apple Inc.',
    ),
    _Credit(
      'Last.fm',
      'Artist information and related-artist data',
      'Data provided by Last.fm. aud.io is not affiliated with or endorsed by '
          'Last.fm / CBS Interactive.',
    ),
  ];

  static final List<_Credit> _libraries = [
    _Credit('yt-dlp', 'Audio stream extraction', 'Unlicense / public domain.'),
    _Credit('just_audio', 'Audio playback engine', 'MIT License © Ryan Heise.'),
    _Credit('audio_service', 'Background playback & media controls', 'MIT License © Ryan Heise.'),
    _Credit('FFmpeg', 'HLS → MP3 transcoding on the server', 'LGPL/GPL © the FFmpeg project.'),
    _Credit('Flutter', 'Application framework', 'BSD 3-Clause © Google LLC.'),
  ];

  static Future<void> exportCredits() async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 48, 40, 48),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(width: 22, height: 22, color: _red),
              pw.SizedBox(width: 10),
              pw.Text('aud.io',
                  style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: _ink)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text('SOURCE ACCREDITATION',
              style: pw.TextStyle(fontSize: 11, letterSpacing: 2, color: _muted)),
          pw.SizedBox(height: 4),
          pw.Text('Generated ${DateTime.now().toIso8601String().split('T').first}',
              style: const pw.TextStyle(fontSize: 9, color: _muted)),
          pw.Divider(color: _ink, thickness: 1.2, height: 28),
          pw.Text(
            'aud.io aggregates music, podcasts and metadata from the third-party '
            'services and open-source projects listed below. All content remains '
            'the property of its respective owners and is surfaced for personal use.',
            style: const pw.TextStyle(fontSize: 10, color: _ink, lineSpacing: 3),
          ),
          pw.SizedBox(height: 22),
          _sectionTitle('DATA SOURCES & APIs'),
          ..._sources.map(_creditBlock),
          pw.SizedBox(height: 18),
          _sectionTitle('OPEN-SOURCE LIBRARIES'),
          ..._libraries.map(_creditBlock),
          pw.SizedBox(height: 24),
          pw.Divider(color: _muted, thickness: 0.5),
          pw.SizedBox(height: 6),
          pw.Text(
            'aud.io is an independent project and is not affiliated with, '
            'sponsored by, or endorsed by any of the services named above. '
            'Trademarks belong to their respective holders.',
            style: const pw.TextStyle(fontSize: 8, color: _muted, lineSpacing: 2),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'aud-io-credits.pdf');
  }

  static pw.Widget _sectionTitle(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: _red,
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)),
        ),
      );

  static pw.Widget _creditBlock(_Credit c) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 14),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(c.name,
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink)),
            pw.SizedBox(height: 2),
            pw.Text(c.role, style: const pw.TextStyle(fontSize: 9, color: _red)),
            pw.SizedBox(height: 3),
            pw.Text(c.notice, style: const pw.TextStyle(fontSize: 9, color: _muted, lineSpacing: 2)),
          ],
        ),
      );
}

class _Credit {
  final String name;
  final String role;
  final String notice;
  const _Credit(this.name, this.role, this.notice);
}
