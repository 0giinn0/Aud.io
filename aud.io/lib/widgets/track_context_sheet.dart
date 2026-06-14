import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/audio_handler.dart';
import 'package:aud_io/services/local_playlist_service.dart';
import 'package:aud_io/widgets/proxied_image.dart';

void showTrackContextMenu(BuildContext context, Track track) {
  final handler = context.read<AppAudioHandler>();
  final playlists = context.read<LocalPlaylistService>();
  final isFav = playlists.isFavorite(track.id);

  showModalBottomSheet(
    context: context,
    backgroundColor: AudIoTheme.surface,
    shape: const RoundedRectangleBorder(),
    builder: (_) => _TrackContextSheet(
      track: track,
      isFavorite: isFav,
      onPlay: () {
        Navigator.pop(context);
        handler.setQueue([track]);
      },
      onAddToQueue: () {
        Navigator.pop(context);
        handler.addToQueue(track);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to queue', style: TextStyle(fontSize: 11, color: AudIoTheme.onSurface)),
            backgroundColor: AudIoTheme.surface,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      onToggleFavorite: () {
        Navigator.pop(context);
        playlists.toggleFavorite(track);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFav ? 'Removed from favorites' : 'Added to favorites',
              style: TextStyle(fontSize: 11, color: AudIoTheme.onSurface),
            ),
            backgroundColor: AudIoTheme.surface,
            duration: const Duration(seconds: 1),
          ),
        );
      },
    ),
  );
}

class _TrackContextSheet extends StatelessWidget {
  final Track track;
  final bool isFavorite;
  final VoidCallback onPlay;
  final VoidCallback onAddToQueue;
  final VoidCallback onToggleFavorite;

  const _TrackContextSheet({
    required this.track,
    required this.isFavorite,
    required this.onPlay,
    required this.onAddToQueue,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AudIoTheme.border, width: 0.5))),
            child: Row(
              children: [
                if (track.thumbnailUrl != null)
                  ProxiedImage(url: track.thumbnailUrl!, width: 40, height: 40,
                    borderRadius: BorderRadius.circular(2),
                    errorBuilder: (_, __, ___) => Container(
                      width: 40, height: 40, color: AudIoTheme.surfaceVariant,
                      child: Icon(Icons.music_note, size: 20, color: AudIoTheme.muted),
                    ),
                  )
                else
                  Container(
                    width: 40, height: 40, color: AudIoTheme.surfaceVariant,
                    child: Icon(Icons.music_note, size: 20, color: AudIoTheme.muted),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title, style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(track.artistDisplay, style: TextStyle(fontSize: 10, color: AudIoTheme.muted),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _ActionTile(icon: Icons.play_arrow_rounded, label: 'Play', onTap: onPlay),
          _ActionTile(icon: Icons.queue_music_rounded, label: 'Add to queue', onTap: onAddToQueue),
          _ActionTile(
            icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onTap: onToggleFavorite,
            color: isFavorite ? AudIoTheme.error : null,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AudIoTheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AudIoTheme.border, width: 0.5))),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 12, color: c)),
          ],
        ),
      ),
    );
  }
}
