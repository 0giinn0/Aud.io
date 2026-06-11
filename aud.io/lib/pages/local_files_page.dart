import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/audio_handler.dart';
import 'package:aud_io/services/local_file_scanner.dart';
import 'package:aud_io/widgets/mini_player.dart';
import 'package:aud_io/widgets/loading_bar.dart';

class LocalFilesPage extends StatefulWidget {
  const LocalFilesPage({super.key});

  @override
  State<LocalFilesPage> createState() => _LocalFilesPageState();
}

class _LocalFilesPageState extends State<LocalFilesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalFileScanner>().scanDevice();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AudIoTheme.bg,
      appBar: AppBar(
        backgroundColor: AudIoTheme.bg,
        elevation: 0,
        title: Text('LOCAL FILES',
          style: TextStyle(fontSize: 11, color: AudIoTheme.primary, letterSpacing: 2)),
        centerTitle: true,
        actions: [
          Consumer<LocalFileScanner>(
            builder: (_, scanner, __) => IconButton(
              icon: Icon(scanner.isScanning ? Icons.hourglass_empty : Icons.refresh,
                color: AudIoTheme.primary, size: 20),
              onPressed: scanner.isScanning ? null : () => scanner.scanDevice(),
            ),
          ),
        ],
      ),
      body: Consumer<LocalFileScanner>(
        builder: (context, scanner, _) {
          if (scanner.isScanning) {
            return LoadingOverlay(
              progress: 0.5,
              status: scanner.scanStatus,
            );
          }

          if (scanner.localTracks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_off, size: 48, color: AudIoTheme.muted),
                  const SizedBox(height: 16),
                  Text('no local files found',
                    style: TextStyle(fontSize: 10, color: AudIoTheme.muted)),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => scanner.scanDevice(),
                    icon: Icon(Icons.refresh, size: 14, color: AudIoTheme.primary),
                    label: Text('scan again', style: TextStyle(color: AudIoTheme.primary)),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: scanner.localTracks.length,
            itemBuilder: (context, index) {
              final track = scanner.localTracks[index];
              return _LocalTrackTile(track: track);
            },
          );
        },
      ),
    );
  }
}

class _LocalTrackTile extends StatelessWidget {
  final Track track;
  const _LocalTrackTile({required this.track});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AudIoTheme.surface,
        border: Border.all(color: AudIoTheme.border, width: 0.5),
      ),
      child: ListTile(
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: AudIoTheme.surfaceVariant,
            border: Border.all(color: AudIoTheme.border, width: 0.5),
          ),
          child: Icon(Icons.music_note, color: AudIoTheme.primary, size: 24),
        ),
        title: Text(track.title,
          style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(track.artistDisplay,
          style: TextStyle(fontSize: 10, color: AudIoTheme.muted)),
        trailing: IconButton(
          icon: Icon(Icons.play_arrow_rounded, color: AudIoTheme.primary, size: 22),
          onPressed: () => context.read<AppAudioHandler>().setQueue([track]),
        ),
        onTap: () => context.read<AppAudioHandler>().setQueue([track]),
      ),
    );
  }
}