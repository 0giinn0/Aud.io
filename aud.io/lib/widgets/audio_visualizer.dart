import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:aud_io/services/audio_handler.dart';
import 'dart:math' as math;

class AudioVisualizer extends StatefulWidget {
  final AppAudioHandler handler;
  final double size;
  final Color? primaryColor;

  const AudioVisualizer({
    super.key,
    required this.handler,
    this.size = 280,
    this.primaryColor,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<double> _bars;
  static const int _barCount = 32;
  StreamSubscription? _playerSub;

  @override
  void initState() {
    super.initState();
    _bars = List.filled(_barCount, 0.1);
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 50))
      ..addListener(_tick);
    _listenToPlayback();
  }

  void _listenToPlayback() {
    _playerSub = widget.handler.player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.playing && !_controller.isAnimating) {
        _controller.repeat();
      } else if (!state.playing && _controller.isAnimating) {
        _controller.stop();
      }
    });
  }

  void _tick() {
    if (!mounted) return;
    try {
      setState(() {
        for (int i = 0; i < _barCount; i++) {
          final decay = 0.9;
          final noise = (math.Random().nextDouble() - 0.5) * 0.1;
          _bars[i] = (_bars[i] * decay + 0.1 + noise).clamp(0.05, 1.0);
        }
      });
    } catch (e) {
      // Ignore visualizer errors
    }
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.primaryColor ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _VisualizerPainter(bars: _bars, color: color),
      ),
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  final List<double> bars;
  final Color color;

  _VisualizerPainter({required this.bars, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = size.width * 0.45;
    final barCount = bars.length;

    for (int i = 0; i < barCount; i++) {
      final angle = (i / barCount) * 2 * math.pi;
      final barHeight = bars[i] * maxRadius;
      final innerRadius = maxRadius * 0.3;
      final outerRadius = innerRadius + barHeight;

      final x1 = centerX + innerRadius * math.cos(angle);
      final y1 = centerY + innerRadius * math.sin(angle);
      final x2 = centerX + outerRadius * math.cos(angle);
      final y2 = centerY + outerRadius * math.sin(angle);

      final hue = (i * 360 / barCount).toInt();
      final paint = Paint()
        ..color = HSVColor.fromAHSV(1.0, hue.toDouble(), 0.8, 0.9).toColor()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }

    final centerPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, centerY), maxRadius * 0.25, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) => true;
}