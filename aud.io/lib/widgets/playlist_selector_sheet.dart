import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/local_playlist_service.dart';

void showPlaylistSelector(BuildContext context, Track track) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AudIoTheme.surface,
    shape: const RoundedRectangleBorder(),
    isScrollControlled: true,
    builder: (_) => _PlaylistSelectorSheet(track: track),
  );
}

class _PlaylistSelectorSheet extends StatefulWidget {
  final Track track;
  const _PlaylistSelectorSheet({required this.track});

  @override
  State<_PlaylistSelectorSheet> createState() => _PlaylistSelectorSheetState();
}

class _PlaylistSelectorSheetState extends State<_PlaylistSelectorSheet> {
  final _nameController = TextEditingController();
  bool _showCreate = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AudIoTheme.border, width: 0.5))),
            child: Row(
              children: [
                Expanded(
                  child: Text('ADD TO PLAYLIST', style: TextStyle(fontSize: 11, color: AudIoTheme.primary, letterSpacing: 2)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showCreate = !_showCreate),
                  child: Icon(_showCreate ? Icons.close_rounded : Icons.add_rounded, size: 20, color: AudIoTheme.primary),
                ),
              ],
            ),
          ),
          if (_showCreate) _buildCreateForm(),
          Consumer<LocalPlaylistService>(
            builder: (context, service, _) {
              if (service.playlists.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _showCreate ? 'create a playlist below' : 'no playlists yet â€” tap + to create one',
                    style: TextStyle(fontSize: 10, color: AudIoTheme.muted),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: service.playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = service.playlists[index];
                    final alreadyHas = playlist.tracks.any((t) => t.id == widget.track.id);
                    return InkWell(
                      onTap: alreadyHas
                          ? null
                          : () {
                              service.addTrackToPlaylist(playlist.id, widget.track);
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.pop(context);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Added to ${playlist.name}',
                                      style: TextStyle(fontSize: 11, color: AudIoTheme.onSurface)),
                                  backgroundColor: AudIoTheme.surface,
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AudIoTheme.border, width: 0.5))),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(playlist.name, style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface)),
                                  const SizedBox(height: 2),
                                  Text('${playlist.trackCount} tracks', style: TextStyle(fontSize: 10, color: AudIoTheme.muted)),
                                ],
                              ),
                            ),
                            if (alreadyHas)
                              Icon(Icons.check_rounded, size: 18, color: AudIoTheme.primary)
                            else
                              Icon(Icons.add_rounded, size: 18, color: AudIoTheme.muted),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return Consumer<LocalPlaylistService>(
      builder: (context, service, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AudIoTheme.border, width: 0.5))),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'playlist name',
                    hintStyle: TextStyle(fontSize: 11, color: AudIoTheme.muted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (v) => _create(service),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _create(service),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AudIoTheme.primary,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Text('CREATE', style: TextStyle(fontSize: 10, color: AudIoTheme.onBg, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _create(LocalPlaylistService service) {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final playlist = service.createPlaylist(name);
    service.addTrackToPlaylist(playlist.id, widget.track);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Created "$name" and added track',
            style: TextStyle(fontSize: 11, color: AudIoTheme.onSurface)),
        backgroundColor: AudIoTheme.surface,
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
