import 'dart:math' as math;
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  final Color? color;
  final int particleCount;
  final double minSize;
  final double maxSize;
  final double minSpeed;
  final double maxSpeed;
  final bool enableGlow;

  const ParticleBackground({
    super.key,
    this.color,
    this.particleCount = 60,
    this.minSize = 1.0,
    this.maxSize = 3.0,
    this.minSpeed = 0.2,
    this.maxSpeed = 0.8,
    this.enableGlow = true,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;
  late final math.Random _random;

  @override
  void initState() {
    super.initState();
    _random = math.Random();
    _particles = List.generate(widget.particleCount, (_) => _Particle.random(_random));
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 30))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            progress: _controller.value,
            color: widget.color,
            enableGlow: widget.enableGlow,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double size;
  final double speedX;
  final double speedY;
  final double phase;
  final double opacity;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.phase,
    required this.opacity,
  });

  factory _Particle.random(math.Random random) {
    return _Particle(
      x: random.nextDouble(),
      y: random.nextDouble(),
      size: 1.0 + random.nextDouble() * 2.5,
      speedX: -0.5 + random.nextDouble(),
      speedY: -0.5 + random.nextDouble(),
      phase: random.nextDouble() * 2 * math.pi,
      opacity: 0.1 + random.nextDouble() * 0.4,
    );
  }

  _Particle update(double progress, Size canvasSize) {
    final double dx = speedX * 0.005;
    final double dy = speedY * 0.005 + math.sin(progress * 2 * math.pi + phase) * 0.001;
    double nx = (x + dx) % 1.0;
    double ny = (y + dy) % 1.0;
    if (nx < 0) nx += 1.0;
    if (ny < 0) ny += 1.0;
    if (nx > 1) nx -= 1.0;
    if (ny > 1) ny -= 1.0;
    return _Particle(
      x: nx,
      y: ny,
      size: size,
      speedX: speedX,
      speedY: speedY,
      phase: phase,
      opacity: opacity,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color? color;
  final bool enableGlow;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    this.color,
    this.enableGlow = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final particle in particles) {
      final updated = particle.update(progress, size);
      final double px = updated.x * size.width;
      final double py = updated.y * size.height;
      final double radius = updated.size;

      paint.color = (color ?? Colors.white).withValues(alpha: updated.opacity);

      if (enableGlow) {
        paint.maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 1.5);
      } else {
        paint.maskFilter = null;
      }

      canvas.drawCircle(Offset(px, py), radius, paint);
    }

    _drawConnections(canvas, size, particles, progress, color ?? Colors.white);
  }

  void _drawConnections(
    Canvas canvas,
    Size size,
    List<_Particle> particles,
    double progress,
    Color color,
  ) {
    final connectPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3
      ..isAntiAlias = true;

    const double maxDist = 120.0;
    const double maxDistSq = maxDist * maxDist;

    for (int i = 0; i < particles.length; i++) {
      final p1 = particles[i];
      final p1x = p1.x * size.width;
      final p1y = p1.y * size.height;

      for (int j = i + 1; j < particles.length; j++) {
        final p2 = particles[j];
        final p2x = p2.x * size.width;
        final p2y = p2.y * size.height;

        final dx = p2x - p1x;
        final dy = p2y - p1y;
        final distSq = dx * dx + dy * dy;

        if (distSq < maxDistSq) {
          final alpha = (1.0 - distSq / maxDistSq) * 0.15;
          connectPaint.color = color.withValues(alpha: alpha);
          canvas.drawLine(Offset(p1x, p1y), Offset(p2x, p2y), connectPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
