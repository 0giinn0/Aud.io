import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:provider/provider.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/core/theme/witty_strings.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/audio_handler.dart';
import 'package:aud_io/services/download_service.dart';
import 'package:aud_io/services/local_playlist_service.dart';
import 'package:aud_io/services/lyrics_service.dart';
import 'package:aud_io/widgets/track_context_sheet.dart';
import 'package:aud_io/widgets/queue_sheet.dart';
import 'package:aud_io/widgets/proxied_image.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _positionSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  late final AnimationController _spinController;

  LyricsResult? _lyrics;
  bool _loadingLyrics = false;
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    _spinController =
        AnimationController(vsync: this, duration: const Duration(seconds: 13));
    final handler = context.read<AppAudioHandler>();
    _positionSub = handler.positionStream.listen((p) {
      if (mounted) {
        setState(() {
          _position = p.position;
          _duration = p.duration;
        });
      }
    });
    _fetchLyrics();
  }

  void _fetchLyrics() {
    final track = context.read<AppAudioHandler>().currentTrack;
    if (track == null) return;
    _loadingLyrics = true;
    LyricsService.fetchLyrics(track.title, track.artistDisplay, duration: track.duration)
        .then((result) {
      if (mounted) {
        setState(() {
          _lyrics = result;
          _loadingLyrics = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _loadingLyrics = false);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String? _currentLyricLine() {
    if (_lyrics?.syncedLines == null || _lyrics!.syncedLines!.isEmpty) return null;
    final lines = _lyrics!.syncedLines!;
    int? found;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (_position >= lines[i].timestamp) {
        found = i;
        break;
      }
    }
    return found != null ? lines[found].text : null;
  }

  @override
  Widget build(BuildContext context) {
    final handler = context.watch<AppAudioHandler>();
    final track = handler.currentTrack;

    return Scaffold(
      backgroundColor: AudIoTheme.red,
      body: SafeArea(
        child: track == null
            ? Center(
                child: Text('nothing playing',
                    style: TextStyle(
                        color: AudIoTheme.ink.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final heroHeight = constraints.maxHeight * AudIoTheme.golden;
                  return Column(
                    children: [
                      SizedBox(
                          height: heroHeight,
                          child: _buildHero(handler, track)),
                      Expanded(child: _buildControls(handler, track)),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildHero(AppAudioHandler handler, Track track) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AudIoTheme.s4, AudIoTheme.s3, AudIoTheme.s4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text('Now\nPlaying',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 0.95,
                      letterSpacing: -1,
                      color: AudIoTheme.ink,
                    )),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 34, color: AudIoTheme.ink),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) {
                  final size =
                      (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight) *
                          0.94;
                  return SizedBox(
                    width: size * 1.06,
                    height: size,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        StreamBuilder<PlayerState>(
                          stream: handler.player.playerStateStream,
                          builder: (_, snap) {
                            final playing = snap.data?.playing ?? false;
                            if (playing && !_spinController.isAnimating) {
                              _spinController.repeat();
                            } else if (!playing && _spinController.isAnimating) {
                              _spinController.stop();
                            }
                            return RotationTransition(
                              turns: _spinController,
                              child: _buildVinyl(track, size),
                            );
                          },
                        ),
                        Positioned(
                          left: 0,
                          bottom: size * 0.13,
                          child: Container(
                            width: size * 0.21,
                            height: size * 0.21,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AudIoTheme.red,
                              border: Border.fromBorderSide(
                                  BorderSide(color: AudIoTheme.ink, width: 3)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVinyl(Track track, double size) {
    final ringWidth = size * 0.09;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AudIoTheme.ink,
      ),
      padding: EdgeInsets.all(ringWidth),
      child: ClipOval(
        child: track.thumbnailUrl != null
            ? ProxiedImage(url: track.thumbnailUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AudIoTheme.surface,
                    child: Icon(Icons.music_note, size: 48, color: AudIoTheme.muted)),
              )
            : _buildVinylLabel(),
      ),
    );
  }

  Widget _buildVinylLabel() {
    return Container(
      color: AudIoTheme.ink,
      child: Center(
        child: Container(
          width: 21,
          height: 21,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AudIoTheme.red,
          ),
        ),
      ),
    );
  }

  Widget _buildControls(AppAudioHandler handler, Track track) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AudIoTheme.s4, AudIoTheme.s2, AudIoTheme.s4, AudIoTheme.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _showLyrics && _lyrics != null
                ? _buildLyricsPanel()
                : _buildTrackInfo(handler, track),
          ),
          const SizedBox(height: AudIoTheme.s2),
          _buildProgressBar(handler),
          const SizedBox(height: AudIoTheme.s3),
          _buildControlButtons(handler, track),
        ],
      ),
    );
  }

  Widget _buildTrackInfo(AppAudioHandler handler, Track track) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lyrics toggle button
              if (_lyrics != null)
                GestureDetector(
                  onTap: () => setState(() => _showLyrics = !_showLyrics),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AudIoTheme.ink.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lyrics_rounded, size: 12, color: AudIoTheme.ink),
                        const SizedBox(width: 4),
                        Text('Lyrics',
                          style: TextStyle(
                            fontSize: 8, fontWeight: FontWeight.w600, color: AudIoTheme.ink)),
                      ],
                    ),
                  ),
                ),
              Text(track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AudIoTheme.ink,
                  )),
              const SizedBox(height: AudIoTheme.s1),
              Text(
                '${track.artistDisplay} · ${track.sourceLabel.toLowerCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AudIoTheme.ink.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: AudIoTheme.s1),
              Text(
                WittyStrings.randomFrom(WittyStrings.nowPlayingJokes),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                  color: AudIoTheme.ink.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AudIoTheme.s3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _fmt(_position),
            style: const TextStyle(
              fontSize: 55,
              fontWeight: FontWeight.w800,
              height: 0.9,
              letterSpacing: -2,
              color: AudIoTheme.ink,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLyricsPanel() {
    if (_loadingLyrics) {
      return const Center(child: CircularProgressIndicator(color: AudIoTheme.ink));
    }
    final lines = _lyrics!.syncedLines;
    if (lines != null && lines.isNotEmpty) {
      final currentLine = _currentLyricLine();
      return GestureDetector(
        onTap: () => setState(() => _showLyrics = false),
        child: ListView(
          padding: EdgeInsets.zero,
          children: lines.map((line) {
            final isCurrent = line.text == currentLine;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                line.text,
                style: TextStyle(
                  fontSize: isCurrent ? 15 : 12,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                  color: isCurrent
                      ? AudIoTheme.ink
                      : AudIoTheme.ink.withValues(alpha: 0.5),
                  height: 1.4,
                ),
              ),
            );
          }).toList(),
        ),
      );
    }
    // Plain text lyrics
    return GestureDetector(
      onTap: () => setState(() => _showLyrics = false),
      child: SingleChildScrollView(
        child: Text(
          _lyrics!.plainText ?? '',
          style: TextStyle(
            fontSize: 13,
            color: AudIoTheme.ink.withValues(alpha: 0.7),
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(AppAudioHandler handler) {
    return Column(
      children: [
        ProgressBar(
          progress: _position,
          buffered: handler.player.bufferedPosition,
          total: _duration,
          onSeek: (pos) => handler.seek(pos),
          barHeight: 3,
          thumbRadius: 6,
          baseBarColor: AudIoTheme.ink.withValues(alpha: 0.25),
          bufferedBarColor: AudIoTheme.ink.withValues(alpha: 0.4),
          progressBarColor: AudIoTheme.ink,
          thumbColor: AudIoTheme.ink,
          timeLabelTextStyle: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AudIoTheme.ink.withValues(alpha: 0.55),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons(AppAudioHandler handler, Track track) {
    return Row(
      children: [
        StreamBuilder<PlayerState>(
          stream: handler.player.playerStateStream,
          builder: (_, snap) {
            final playing = snap.data?.playing ?? false;
            return GestureDetector(
              onTap: () => playing ? handler.pause() : handler.play(),
              child: Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AudIoTheme.ink,
                ),
                child: Icon(
                  playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 34,
                  color: AudIoTheme.red,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: AudIoTheme.s3),
        _flatButton(Icons.skip_previous_rounded, 28,
            onTap: () => handler.skipToPrevious()),
        _flatButton(Icons.skip_next_rounded, 28,
            onTap: () => handler.skipToNext()),
        StreamBuilder<AudioServiceShuffleMode>(
          stream: handler.playbackState.map((s) => s.shuffleMode),
          builder: (_, snap) {
            final on = snap.data == AudioServiceShuffleMode.all;
            return _flatButton(Icons.shuffle_rounded, 21,
                dimmed: !on, onTap: () => handler.toggleShuffle());
          },
        ),
        StreamBuilder<AudioServiceRepeatMode>(
          stream: handler.playbackState.map((s) => s.repeatMode),
          builder: (_, snap) {
            final mode = snap.data ?? AudioServiceRepeatMode.none;
            return _flatButton(
                mode == AudioServiceRepeatMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                21,
                dimmed: mode == AudioServiceRepeatMode.none,
                onTap: () => handler.cycleRepeatMode());
          },
        ),
        const Spacer(),
        Consumer<LocalPlaylistService>(
          builder: (_, favService, __) {
            final isFav = favService.isFavorite(track.id);
            return _flatButton(
                isFav
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                21,
                dimmed: !isFav,
                onTap: () => favService.toggleFavorite(track));
          },
        ),
        _downloadButton(track),
        _flatButton(Icons.queue_music_rounded, 22,
            onTap: () => showQueueSheet(context)),
        _flatButton(Icons.more_horiz_rounded, 24,
            onTap: () => showTrackContextMenu(context, track)),
      ],
    );
  }

  Widget _flatButton(IconData icon, double size,
      {bool dimmed = false, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(AudIoTheme.s2),
        child: Icon(icon,
            size: size,
            color: dimmed
                ? AudIoTheme.ink.withValues(alpha: 0.35)
                : AudIoTheme.ink),
      ),
    );
  }

  Widget _downloadButton(Track track) {
    return Consumer<DownloadService>(
      builder: (_, dlService, __) {
        final isDl = dlService.isDownloaded(track.id);
        final dlTask = dlService.tasks[track.id];
        final isDownloading = dlTask?.status == DownloadStatus.downloading;

        if (isDownloading) {
          return Padding(
            padding: const EdgeInsets.all(AudIoTheme.s2),
            child: SizedBox(
              width: 21,
              height: 21,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: dlTask!.progress > 0 ? dlTask.progress : null,
                color: AudIoTheme.ink,
              ),
            ),
          );
        }
        return _flatButton(
            isDl ? Icons.download_done_rounded : Icons.download_rounded, 21,
            dimmed: !isDl, onTap: () {
          if (isDl) {
            dlService.deleteTrack(track.id);
          } else {
            dlService.downloadTrack(track.id, track.source);
          }
        });
      },
    );
  }
}
