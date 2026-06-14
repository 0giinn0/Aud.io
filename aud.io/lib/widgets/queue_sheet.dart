import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/audio_handler.dart';
import 'package:aud_io/widgets/proxied_image.dart';

/// Shows the current play queue as draggable cards. Reordering a card moves
/// the track in the player queue; this works for music tracks, podcast
/// episodes, liked songs and playlists alike (they all become queue tracks).
void showQueueSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AudIoTheme.bg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _QueueSheet(),
  );
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Consumer<AppAudioHandler>(
          builder: (context, handler, _) {
            final queue = handler.queueList;
            final current = handler.currentIndex;
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AudIoTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                  child: Row(
                    children: [
                      Icon(Icons.queue_music_rounded, size: 20, color: AudIoTheme.primary),
                      const SizedBox(width: 10),
                      Text('Up Next', style: TextStyle(
                        fontSize: 16, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('${queue.length} tracks · drag to reorder',
                        style: TextStyle(fontSize: 10, color: AudIoTheme.subtle)),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                Expanded(
                  child: queue.isEmpty
                      ? Center(child: Text('Queue is empty',
                          style: TextStyle(fontSize: 12, color: AudIoTheme.muted)))
                      : ReorderableListView.builder(
                          scrollController: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          itemCount: queue.length,
                          onReorder: handler.reorderQueue,
                          itemBuilder: (context, index) {
                            final track = queue[index];
                            final isCurrent = index == current;
                            return _QueueCard(
                              key: ValueKey('${track.id}_$index'),
                              track: track,
                              index: index,
                              isCurrent: isCurrent,
                              onTap: () => handler.skipToQueueItem(index),
                              onRemove: () => handler.removeFromQueue(index),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _QueueCard extends StatelessWidget {
  final Track track;
  final int index;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _QueueCard({
    required super.key,
    required this.track,
    required this.index,
    required this.isCurrent,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isCurrent ? AudIoTheme.primary.withValues(alpha: 0.14) : AudIoTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: isCurrent ? Border.all(color: AudIoTheme.primary, width: 1) : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (track.thumbnailUrl != null)
                ProxiedImage(url: track.thumbnailUrl!, width: 44, height: 44, borderRadius: BorderRadius.circular(8),
                  errorBuilder: (_, __, ___) => _placeholder())
              else
                _placeholder(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(track.title, style: TextStyle(
                      fontSize: 12,
                      color: isCurrent ? AudIoTheme.primary : AudIoTheme.onSurface,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${track.artistDisplay} · ${track.sourceShort.toLowerCase()}',
                      style: TextStyle(fontSize: 10, color: AudIoTheme.subtle),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.close_rounded, size: 16, color: AudIoTheme.subtle),
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Icon(Icons.drag_handle_rounded, size: 20, color: AudIoTheme.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: AudIoTheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
        child: Icon(track.source == TrackSource.podcast ? Icons.podcasts_rounded : Icons.music_note_rounded,
          size: 18, color: AudIoTheme.subtle),
      );
}
