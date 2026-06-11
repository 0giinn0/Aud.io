import 'dart:math';
import 'package:flutter/material.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';

class FakeAlbum {
  final String title;
  final String genre;
  final Color bg;
  final Color accent;
  final String? artist;
  final String? thumbnailUrl;
  final String? source;

  const FakeAlbum({
    required this.title,
    this.genre = 'ambient',
    this.bg = const Color(0xFF1A1A2E),
    this.accent = const Color(0xFFE94560),
    this.artist,
    this.thumbnailUrl,
    this.source,
  });

  static final List<String> _titles = [
    'midnight.exe', 'tetris effect', 'buffer underrun', 'segfault waltz',
    'null pointer', 'memory leak', 'fork bomb', 'race condition',
    'deadlock serenade', 'infinite loop', 'cache me outside', 'bit rot',
    'booting...', 'sudo make coffee', 'ping of death', 'kernel panic',
    'blue screen of death', 'has anyone really', 'the cake is a lie',
    'all your bass', 'merge conflict', 'undefined behavior', 'off by one',
  ];

  static final List<String> _genres = [
    'lo-fi', 'synthwave', 'jazz', 'ambient', 'breakcore',
    'vaporwave', 'drum & bass', 'shoegaze', 'idm', 'footwork',
  ];

  static final List<Color> _bgColors = [
    const Color(0xFF1A1A2E), const Color(0xFF16213E), const Color(0xFF0F3460),
    const Color(0xFF533483), const Color(0xFF2D2D44), const Color(0xFF1C1C3A),
    const Color(0xFF2A1B38), const Color(0xFF1B2838), const Color(0xFF382A1B),
    const Color(0xFF1B382A), const Color(0xFF3A1B1B), const Color(0xFF1B1B3A),
  ];

  static final List<Color> _accentColors = [
    const Color(0xFFE94560), const Color(0xFF0F3460), const Color(0xFF8B5CF6),
    const Color(0xFF06D6A0), const Color(0xFFEF476F), const Color(0xFFFFD166),
    const Color(0xFF118AB2), const Color(0xFF073B4C), const Color(0xFF7B2CBF),
    const Color(0xFFF72585), const Color(0xFF4CC9F0), const Color(0xFF4895EF),
  ];

  static List<FakeAlbum> generate(int count, {int seed = 42}) {
    final rng = Random(seed);
    return List.generate(count, (i) {
      final bgIdx = rng.nextInt(_bgColors.length);
      final accentIdx = (bgIdx + 1 + rng.nextInt(_bgColors.length - 1)) % _bgColors.length;
      return FakeAlbum(
        title: _titles[rng.nextInt(_titles.length)],
        genre: _genres[rng.nextInt(_genres.length)],
        bg: _bgColors[bgIdx],
        accent: _accentColors[accentIdx],
      );
    });
  }

  static List<FakeAlbum> fromTracks(List<Object?> tracks, {int take = 500}) {
    final seed = tracks.isEmpty ? 42 : tracks.length;
    return generate(take > tracks.length ? tracks.length : take, seed: seed);
  }
}

class FisheyeGrid extends StatefulWidget {
  final List<FakeAlbum> albums;
  final double cellWidth;
  final double cellHeight;
  final void Function(FakeAlbum album)? onAlbumTap;
  final void Function(FakeAlbum album, int index)? onAlbumLongPress;

  const FisheyeGrid({
    super.key,
    required this.albums,
    this.cellWidth = 110,
    this.cellHeight = 110,
    this.onAlbumTap,
    this.onAlbumLongPress,
  });

  @override
  State<FisheyeGrid> createState() => _FisheyeGridState();
}

class _FisheyeGridState extends State<FisheyeGrid>
    with SingleTickerProviderStateMixin {
  Offset? _pointer;
  bool _pressed = false;

  late final AnimationController _springCtrl;

  @override
  void initState() {
    super.initState();
    _springCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _springCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _springCtrl.dispose();
    super.dispose();
  }

  double get _lensRadius => _springCtrl.value * 0.35;
  double get _lensStrength => _springCtrl.value * 0.6;

  Offset _fisheye(Offset pos, Size size) {
    if (_pointer == null || _lensRadius < 0.001) return pos;

    final dx = pos.dx - _pointer!.dx;
    final dy = pos.dy - _pointer!.dy;
    final dist = sqrt(dx * dx + dy * dy);
    final r = _lensRadius * size.shortestSide;

    if (dist >= r) return pos;

    final nd = dist / r;
    final falloff = 1 - nd * nd;
    final displacement = falloff * _lensStrength * (r - dist) * 0.3;

    if (dist < 0.001) return pos;

    final ratio = (dist + displacement) / dist;
    return Offset(
      _pointer!.dx + dx * ratio,
      _pointer!.dy + dy * ratio,
    );
  }

  double _itemScale(Offset pos, Size size) {
    if (_pointer == null || _lensRadius < 0.001) return 1;

    final dx = pos.dx - _pointer!.dx;
    final dy = pos.dy - _pointer!.dy;
    final dist = sqrt(dx * dx + dy * dy);
    final r = _lensRadius * size.shortestSide;

    if (dist >= r) return 1;

    final nd = dist / r;
    final falloff = 1 - nd * nd;
    return 1 + falloff * _lensStrength * 0.5;
  }

  int? _hitTestIndex(Offset pos, Size size) {
    final cols = (size.width / widget.cellWidth).ceil();
    final rows = (size.height / widget.cellHeight).ceil();
    final cw = size.width / cols;
    final ch = size.height / rows;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final idx = r * cols + c;
        if (idx >= widget.albums.length) break;

        final origCenter = Offset(c * cw + cw / 2, r * ch + ch / 2);
        final scale = _itemScale(origCenter, size);
        final center = _fisheye(origCenter, size);
        final w = cw * scale;
        final h = ch * scale;
        final x = center.dx - w / 2;
        final y = center.dy - h / 2;

        if (pos.dx >= x && pos.dx <= x + w && pos.dy >= y && pos.dy <= y + h) {
          return idx;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final cols = (size.width / widget.cellWidth).ceil();
        final rows = (size.height / widget.cellHeight).ceil();
        final cw = size.width / cols;
        final ch = size.height / rows;

        return GestureDetector(
          onTapUp: widget.onAlbumTap != null ? (d) {
            final idx = _hitTestIndex(d.localPosition, size);
            if (idx != null && idx < widget.albums.length) {
              widget.onAlbumTap!(widget.albums[idx]);
            }
          } : null,
          onLongPressStart: widget.onAlbumLongPress != null ? (d) {
            final idx = _hitTestIndex(d.localPosition, size);
            if (idx != null && idx < widget.albums.length) {
              widget.onAlbumLongPress!(widget.albums[idx], idx);
            }
            setState(() {
              _pointer = d.localPosition;
              _pressed = true;
            });
            _springCtrl.forward();
          } : (d) {
            setState(() {
              _pointer = d.localPosition;
              _pressed = true;
            });
            _springCtrl.forward();
          },
          onLongPressMoveUpdate: (d) {
            setState(() { _pointer = d.localPosition; });
          },
          onLongPressEnd: (_) {
            setState(() => _pressed = false);
            _springCtrl.reverse();
          },
          child: ClipRect(
            child: CustomPaint(
              size: size,
              painter: _FisheyeGridPainter(
                albums: widget.albums,
                cols: cols,
                rows: rows,
                cellWidth: cw,
                cellHeight: ch,
                pointer: _pointer,
                pressed: _pressed,
                lensRadius: _lensRadius,
                lensStrength: _lensStrength,
                fisheyeFn: _fisheye,
                scaleFn: _itemScale,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FisheyeGridPainter extends CustomPainter {
  final List<FakeAlbum> albums;
  final int cols;
  final int rows;
  final double cellWidth;
  final double cellHeight;
  final Offset? pointer;
  final bool pressed;
  final double lensRadius;
  final double lensStrength;
  final Offset Function(Offset, Size) fisheyeFn;
  final double Function(Offset, Size) scaleFn;

  _FisheyeGridPainter({
    required this.albums,
    required this.cols,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.pointer,
    required this.pressed,
    required this.lensRadius,
    required this.lensStrength,
    required this.fisheyeFn,
    required this.scaleFn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final bgPaint = Paint()..color = AudIoTheme.bg;
      canvas.drawRect(Offset.zero & size, bgPaint);

      for (int r = 0; r < rows && r < 100; r++) {
        for (int c = 0; c < cols && c < 100; c++) {
          final idx = r * cols + c;
          if (idx >= albums.length) break;
          final album = albums[idx];

          final origCenter = Offset(c * cellWidth + cellWidth / 2, r * cellHeight + cellHeight / 2);
          final scale = scaleFn(origCenter, size);
          final center = fisheyeFn(origCenter, size);

          final w = cellWidth * scale;
          final h = cellHeight * scale;
          final x = center.dx - w / 2;
          final y = center.dy - h / 2;
          final rect = Rect.fromLTWH(x, y, w, h);

          if (x + w < -20 || y + h < -20 || x > size.width + 20 || y > size.height + 20) continue;

          final cardPaint = Paint()..color = album.bg;
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), cardPaint);

          // Gradient overlay
          final gradientPaint = Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                album.accent.withValues(alpha: 0.0),
                album.accent.withValues(alpha: 0.15),
              ],
            ).createShader(rect);
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), gradientPaint);

          final borderPaint = Paint()
            ..color = AudIoTheme.border
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), borderPaint);

          final barCount = 4;
          final barW = (w - 16) / barCount;
          for (int b = 0; b < barCount; b++) {
            final bh = 6.0 + (idx * 17 + b * 31) % 20;
            final barPaint = Paint()
              ..color = album.accent.withValues(alpha: 0.3 + ((idx * 7 + b * 13) % 50) / 100);
            final barRect = Rect.fromLTWH(x + 8 + b * barW, y + h - 28 - bh, barW - 2, bh);
            canvas.drawRect(barRect, barPaint);
          }

          if (w > 40) {
            final fontSize = (w * 0.09).clamp(6.0, 10.0);
            final titleStyle = TextStyle(color: AudIoTheme.onSurface, fontSize: fontSize);
            final tp = TextPainter(
              text: TextSpan(text: album.title, style: titleStyle),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              ellipsis: 'â€¦',
            );
            tp.layout(maxWidth: w - 12);
            tp.paint(canvas, Offset(x + 6, y + 8));

            final subtitle = album.artist ?? album.genre;
            final subStyle = TextStyle(color: AudIoTheme.muted, fontSize: fontSize - 1);
            final gp = TextPainter(text: TextSpan(text: subtitle, style: subStyle), textDirection: TextDirection.ltr);
            gp.layout(maxWidth: w - 12);
            gp.paint(canvas, Offset(x + 6, y + h - 8 - (fontSize - 1)));
          }
        }
      }

      if (pressed && pointer != null && lensRadius > 0.02) {
        final r = lensRadius * size.shortestSide;
        final circlePaint = Paint()
          ..color = AudIoTheme.border.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5;
        canvas.drawCircle(pointer!, r, circlePaint);

        final dotPaint = Paint()..color = AudIoTheme.primary;
        canvas.drawCircle(pointer!, 2, dotPaint);
      }
    } catch (e) {
      // Ignore paint errors
    }
  }

  @override
  bool shouldRepaint(_FisheyeGridPainter old) =>
      old.pointer != pointer || old.pressed != pressed ||
      old.lensRadius != lensRadius || old.lensStrength != lensStrength;
}
