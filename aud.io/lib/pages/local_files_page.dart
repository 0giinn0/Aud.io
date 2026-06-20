import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/local_file_scanner.dart';
import 'package:aud_io/services/audio_handler.dart';

class LocalFilesPage extends StatelessWidget {
  const LocalFilesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AudIoTheme.bg,
      body: Consumer<LocalFileScanner>(
        builder: (context, scanner, _) {
          final handler = context.watch<AppAudioHandler>();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Local Files', style: TextStyle(
                          fontSize: 22, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
                        Text(scanner.tracks.isEmpty
                            ? 'No files found yet'
                            : '${scanner.tracks.length} audio file${scanner.tracks.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 11, color: AudIoTheme.subtle)),
                      ],
                    ),
                  ),
                  if (scanner.isScanning)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AudIoTheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text('FIND MUSIC', style: TextStyle(
                fontSize: 12, color: AudIoTheme.muted,
                fontWeight: FontWeight.w600, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _ActionCard(
                  icon: Icons.storage_rounded,
                  label: 'Scan Device',
                  sublabel: scanner.isScanning ? 'Scanning…' : 'Auto-find music',
                  accent: AudIoTheme.primary,
                  disabled: scanner.isScanning,
                  onTap: () => scanner.scan(),
                )),
                const SizedBox(width: 12),
                Expanded(child: _ActionCard(
                  icon: Icons.folder_open_rounded,
                  label: 'Pick Folder',
                  sublabel: 'Choose a directory',
                  accent: AudIoTheme.primary,
                  disabled: scanner.isScanning,
                  onTap: () => scanner.pickDirectory(),
                )),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _ActionCard(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Pick Files',
                  sublabel: 'Select audio files',
                  accent: AudIoTheme.primary,
                  disabled: scanner.isScanning,
                  onTap: () => scanner.pickFiles(),
                )),
                const SizedBox(width: 12),
                Expanded(child: _ActionCard(
                  icon: Icons.delete_sweep_outlined,
                  label: 'Clear',
                  sublabel: 'Remove all local tracks',
                  accent: AudIoTheme.error,
                  disabled: scanner.tracks.isEmpty,
                  onTap: () => scanner.clear(),
                )),
              ]),

              if (scanner.lastScanPath.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AudIoTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.folder_rounded, size: 13, color: AudIoTheme.subtle),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(scanner.lastScanPath,
                          style: TextStyle(fontSize: 9, color: AudIoTheme.subtle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ],

              if (scanner.tracks.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(children: [
                  Text('TRACKS', style: TextStyle(
                    fontSize: 12, color: AudIoTheme.muted,
                    fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => handler.setQueue(scanner.tracks, startIndex: 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AudIoTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.shuffle_rounded, size: 12, color: AudIoTheme.primary),
                        const SizedBox(width: 4),
                        Text('Shuffle All', style: TextStyle(
                          fontSize: 10, color: AudIoTheme.primary, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                ...scanner.tracks.asMap().entries.map((e) => _LocalTrackTile(
                  track: e.value,
                  index: e.key,
                  onPlay: () => handler.setQueue(scanner.tracks, startIndex: e.key),
                )),
              ] else if (!scanner.isScanning) ...[
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.folder_open_rounded, size: 40, color: AudIoTheme.surfaceVariant),
                      const SizedBox(height: 12),
                      Text('No local files yet', style: TextStyle(
                        fontSize: 13, color: AudIoTheme.muted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Scan your device or pick files above', style: TextStyle(
                        fontSize: 10, color: AudIoTheme.subtle)),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color accent;
  final bool disabled;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.accent,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.45 : 1.0,
        child: Container(
          height: 90,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AudIoTheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: accent),
              const Spacer(),
              Text(label, style: TextStyle(
                fontSize: 13, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
              Text(sublabel, style: TextStyle(
                fontSize: 9, color: AudIoTheme.subtle)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalTrackTile extends StatelessWidget {
  final Track track;
  final int index;
  final VoidCallback onPlay;

  const _LocalTrackTile({required this.track, required this.index, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPlay,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AudIoTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AudIoTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(Icons.music_note_rounded, size: 16, color: AudIoTheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title, style: TextStyle(
                    fontSize: 12, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(track.artist ?? '', style: TextStyle(
                    fontSize: 10, color: AudIoTheme.subtle),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.play_arrow_rounded, size: 18, color: AudIoTheme.subtle),
          ],
        ),
      ),
    );
  }
}
