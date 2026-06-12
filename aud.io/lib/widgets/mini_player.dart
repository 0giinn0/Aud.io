import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/core/theme/witty_strings.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/audio_handler.dart';
import 'package:aud_io/services/download_service.dart';

/// Bauhaus mini player: ink bar with hard edges, circular art, red circle
/// play button, thin red progress line along the top.
class MiniPlayer extends StatelessWidget {
  final Track track;
  final AppAudioHandler audioHandler;
  final VoidCallback onTap;

  const MiniPlayer({
    super.key,
    required this.track,
    required this.audioHandler,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadService>(
      builder: (context, downloadService, _) {
        final isDownloaded = downloadService.isDownloaded(track.id);
        final task = downloadService.tasks[track.id];
        final isDownloading = task?.status == DownloadStatus.downloading;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 55,
            color: AudIoTheme.ink,
            child: Column(
              children: [
                // Progress line along the top edge.
                StreamBuilder<PositionData>(
                  stream: audioHandler.positionStream,
                  builder: (context, snapshot) {
                    final pos = snapshot.data?.position ?? Duration.zero;
                    final dur = snapshot.data?.duration ?? Duration.zero;
                    final progress = dur.inMilliseconds > 0
                        ? pos.inMilliseconds / dur.inMilliseconds
                        : 0.0;
                    return LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: AudIoTheme.cream.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(AudIoTheme.red),
                      minHeight: 2,
                    );
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AudIoTheme.s3),
                    child: Row(
                      children: [
                        // Circular album art.
                        ClipOval(
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: track.thumbnailUrl != null
                                ? Image.network(
                                    track.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _artFallback(),
                                  )
                                : _artFallback(),
                          ),
                        ),
                        const SizedBox(width: AudIoTheme.s3),
                        // Track info.
                        Expanded(
                          child: Tooltip(
                            message: WittyStrings.randomFrom(WittyStrings.nowPlayingJokes),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AudIoTheme.cream,
                                    )),
                                const SizedBox(height: 1),
                                Text(
                                  '${track.artistDisplay} · ${track.sourceShort.toLowerCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                    color: AudIoTheme.cream.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isDownloaded || isDownloading)
                          Padding(
                            padding: const EdgeInsets.only(right: AudIoTheme.s2),
                            child: Icon(
                              isDownloaded
                                  ? Icons.download_done_rounded
                                  : Icons.download_rounded,
                              size: 14,
                              color: AudIoTheme.cream.withValues(alpha: 0.55),
                            ),
                          ),
                        // Red circle play/pause.
                        StreamBuilder<PlayerState>(
                          stream: audioHandler.player.playerStateStream,
                          builder: (context, snapshot) {
                            final isPlaying = snapshot.data?.playing ?? false;
                            return GestureDetector(
                              onTap: () => isPlaying
                                  ? audioHandler.pause()
                                  : audioHandler.play(),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AudIoTheme.red,
                                ),
                                child: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 21,
                                  color: AudIoTheme.ink,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: AudIoTheme.s2),
                        GestureDetector(
                          onTap: () => audioHandler.skipToNext(),
                          child: Icon(Icons.skip_next_rounded,
                              size: 24,
                              color: AudIoTheme.cream.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _artFallback() {
    return Container(
      color: AudIoTheme.red,
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AudIoTheme.ink,
          ),
        ),
      ),
    );
  }
}
