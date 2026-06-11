import 'package:flutter/material.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/widgets/particle_background.dart';

class LoadingBar extends StatefulWidget {
  final double progress;
  final String status;
  final double width;
  final double height;

  const LoadingBar({
    super.key,
    required this.progress,
    required this.status,
    this.width = 240,
    this.height = 3,
  });

  @override
  State<LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<LoadingBar> with SingleTickerProviderStateMixin {
  late final AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat();
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.status,
              style: TextStyle(fontSize: 11, color: AudIoTheme.muted, letterSpacing: 1.5)),
            const SizedBox(width: 4),
            AnimatedBuilder(
              animation: _cursorController,
              builder: (_, __) => Opacity(
                opacity: _cursorController.value < 0.5 ? 1.0 : 0.0,
                child: Text('_', style: TextStyle(fontSize: 11, color: AudIoTheme.muted)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AudIoTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: AudIoTheme.border, width: 0.5),
                ),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: widget.progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AudIoTheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text('${(widget.progress * 100).round()}%',
          style: TextStyle(fontSize: 11, color: AudIoTheme.muted, letterSpacing: 0.5)),
      ],
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final double progress;
  final String status;
  final bool showEnterButton;
  final VoidCallback? onEnterTap;

  const LoadingOverlay({
    super.key,
    required this.progress,
    required this.status,
    this.showEnterButton = false,
    this.onEnterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ParticleBackground(
          particleCount: 50,
          minSize: 1.0,
          maxSize: 3.5,
          minSpeed: 0.15,
          maxSpeed: 0.6,
          enableGlow: true,
        ),
        Container(color: AudIoTheme.bg.withValues(alpha: 0.95)),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoadingBar(progress: progress, status: status),
              if (showEnterButton) ...[
                const SizedBox(height: 32),
                Text('click to enter', style: TextStyle(fontSize: 11, color: AudIoTheme.muted, letterSpacing: 1.5)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onEnterTap,
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AudIoTheme.muted, width: 1),
                    ),
                    child: Center(
                      child: Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AudIoTheme.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}