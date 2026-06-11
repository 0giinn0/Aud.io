import 'package:flutter/material.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/services/sound_synthesizer.dart';

class InstrumentBuilderPage extends StatefulWidget {
  const InstrumentBuilderPage({super.key});

  @override
  State<InstrumentBuilderPage> createState() => _InstrumentBuilderPageState();
}

class _InstrumentBuilderPageState extends State<InstrumentBuilderPage> {
  int _bpm = 120;
  bool _isPlaying = false;
  int _currentStep = -1;
  final Set<int> _activeSteps = {};
  final Set<int> _pressedKeys = {};

  static const List<String> _noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  static const List<bool> _isBlackKey = [false, true, false, true, false, false, true, false, true, false, true, false];
  static const List<double> _noteFreqs = [
    261.63, 277.18, 293.66, 311.13, 329.63, 349.23, 369.99, 392.00, 415.30, 440.00, 466.16, 493.88,
  ];

  // Wave type selector
  String _waveType = 'sine';

  void _playNote(int noteIndex, {double duration = 0.3}) {
    final freq = _noteFreqs[noteIndex];
    SoundSynthesizer.playNote(freq, duration: duration, waveType: _waveType);
  }

  void _playStepNote(int step) {
    for (int beat = 0; beat < 4; beat++) {
      if (_activeSteps.contains(step * 4 + beat)) {
        _playNote((step + beat * 3) % 12, duration: 0.15);
      }
    }
  }

  void _toggleBeat(int beatIdx) {
    setState(() {
      if (_activeSteps.contains(beatIdx)) {
        _activeSteps.remove(beatIdx);
      } else {
        _activeSteps.add(beatIdx);
      }
    });
  }

  void _toggleStep(int step) {
    setState(() {
      final all4 = List.generate(4, (b) => step * 4 + b);
      final allActive = all4.every(_activeSteps.contains);
      if (allActive) {
        _activeSteps.removeAll(all4);
      } else {
        _activeSteps.addAll(all4);
      }
    });
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (!_isPlaying) _currentStep = -1;
    });
    if (_isPlaying) _runSequencer();
  }

  Future<void> _runSequencer() async {
    final stepDuration = Duration(milliseconds: (60000 / _bpm / 4).round());
    while (_isPlaying && mounted) {
      setState(() => _currentStep = (_currentStep + 1) % 16);
      _playStepNote(_currentStep);
      await Future.delayed(stepDuration);
    }
  }

  void _clearAll() {
    setState(() {
      _activeSteps.clear();
      _currentStep = -1;
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AudIoTheme.bg,
      body: Column(
        children: [
          _buildHeader(),
          _buildTransport(),
          const SizedBox(height: 8),
          _buildSequencerGrid(),
          const SizedBox(height: 8),
          _buildWaveSelector(),
          const SizedBox(height: 8),
          _buildKeyboard(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('STUDIO', style: TextStyle(
                fontSize: 11, color: AudIoTheme.primary, fontWeight: FontWeight.w600, letterSpacing: 2)),
              const SizedBox(height: 2),
              Text('beat maker & synthesizer', style: TextStyle(
                fontSize: 10, color: AudIoTheme.subtle)),
            ],
          ),
          const Spacer(),
          _buildBpmChip(),
        ],
      ),
    );
  }

  Widget _buildBpmChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AudIoTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _bpm = (_bpm - 5).clamp(40, 300)),
            child: Icon(Icons.remove_rounded, size: 16, color: AudIoTheme.muted),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$_bpm', style: TextStyle(
              fontSize: 13, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
          ),
          GestureDetector(
            onTap: () => setState(() => _bpm = (_bpm + 5).clamp(40, 300)),
            child: Icon(Icons.add_rounded, size: 16, color: AudIoTheme.muted),
          ),
          const SizedBox(width: 4),
          Text('BPM', style: TextStyle(
            fontSize: 9, color: AudIoTheme.subtle)),
        ],
      ),
    );
  }

  Widget _buildTransport() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AudIoTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTransportBtn(
              icon: Icons.fiber_manual_record_rounded,
              color: AudIoTheme.error,
              isActive: false,
              onTap: () {},
            ),
            _buildTransportBtn(
              icon: Icons.skip_previous_rounded,
              color: AudIoTheme.muted,
              isActive: false,
              onTap: () => setState(() => _currentStep = -1),
            ),
            GestureDetector(
              onTap: _togglePlayback,
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isPlaying ? AudIoTheme.primary : AudIoTheme.onSurface,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 28, color: _isPlaying ? AudIoTheme.onBg : AudIoTheme.bg,
                ),
              ),
            ),
            _buildTransportBtn(
              icon: Icons.skip_next_rounded,
              color: AudIoTheme.muted,
              isActive: false,
              onTap: () {},
            ),
            _buildTransportBtn(
              icon: Icons.delete_outline_rounded,
              color: AudIoTheme.subtle,
              isActive: false,
              onTap: _clearAll,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportBtn({
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? color.withValues(alpha: 0.15) : AudIoTheme.surfaceVariant,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildSequencerGrid() {
    return Expanded(
      flex: 3,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 16,
        itemBuilder: (context, step) {
          final isActive = _currentStep == step;
          final hasNote = List.generate(4, (b) => step * 4 + b).any(_activeSteps.contains);
          return GestureDetector(
            onTap: () => _toggleStep(step),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              margin: const EdgeInsets.only(bottom: 3),
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? AudIoTheme.primary.withValues(alpha: 0.25)
                    : hasNote
                        ? AudIoTheme.primary.withValues(alpha: 0.12)
                        : AudIoTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isActive ? AudIoTheme.primary : AudIoTheme.border,
                  width: isActive ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${step + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: isActive ? AudIoTheme.primary : AudIoTheme.subtle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: List.generate(4, (beat) {
                        final beatIdx = step * 4 + beat;
                        final isBeatActive = _activeSteps.contains(beatIdx);
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _toggleBeat(beatIdx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 60),
                              margin: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: isBeatActive
                                    ? AudIoTheme.primary
                                    : AudIoTheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: isBeatActive
                                  ? Center(
                                      child: Container(
                                        width: 6, height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AudIoTheme.onBg,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaveSelector() {
    final waves = [
      {'name': 'sine', 'icon': Icons.waves_rounded},
      {'name': 'square', 'icon': Icons.crop_square_rounded},
      {'name': 'sawtooth', 'icon': Icons.show_chart_rounded},
      {'name': 'triangle', 'icon': Icons.change_history_rounded},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: waves.map((w) {
          final isSelected = _waveType == w['name'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _waveType = w['name'] as String);
                // Preview the sound
                _playNote(6, duration: 0.2);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AudIoTheme.primary.withValues(alpha: 0.15) : AudIoTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AudIoTheme.primary : AudIoTheme.border,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(w['icon'] as IconData, size: 18,
                      color: isSelected ? AudIoTheme.primary : AudIoTheme.subtle),
                    const SizedBox(height: 4),
                    Text((w['name'] as String).toUpperCase(), style: TextStyle(
                      fontSize: 8, color: isSelected ? AudIoTheme.primary : AudIoTheme.subtle,
                      fontWeight: FontWeight.w600, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKeyboard() {
    return SizedBox(
      height: 120,
      child: Row(
        children: List.generate(12, (i) {
          final isBlack = _isBlackKey[i];
          final isPressed = _pressedKeys.contains(i);
          return Expanded(
            child: GestureDetector(
              onTapDown: (_) {
                _playNote(i, duration: 0.5);
                setState(() => _pressedKeys.add(i));
              },
              onTapUp: (_) => setState(() => _pressedKeys.remove(i)),
              onTapCancel: () => setState(() => _pressedKeys.remove(i)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 50),
                margin: EdgeInsets.only(
                  left: isBlack ? 0 : 1,
                  right: isBlack ? 0 : 1,
                ),
                decoration: BoxDecoration(
                  color: isPressed
                      ? AudIoTheme.primary.withValues(alpha: 0.3)
                      : isBlack
                          ? AudIoTheme.onBg
                          : AudIoTheme.surface,
                  borderRadius: BorderRadius.only(
                    bottomLeft: const Radius.circular(6),
                    bottomRight: const Radius.circular(6),
                  ),
                  border: Border.all(
                    color: isPressed ? AudIoTheme.primary : AudIoTheme.border,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _noteNames[i],
                        style: TextStyle(
                          fontSize: 8,
                          color: isBlack ? AudIoTheme.bg : AudIoTheme.subtle,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
