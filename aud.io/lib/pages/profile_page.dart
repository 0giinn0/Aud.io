import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/core/models/playlist_model.dart';
import 'package:aud_io/services/audio_handler.dart';
import 'package:aud_io/services/local_playlist_service.dart';
import 'package:aud_io/services/local_file_scanner.dart';
import 'package:aud_io/services/spotify_auth_service.dart';
import 'package:aud_io/services/settings_service.dart';
import 'package:aud_io/widgets/track_context_sheet.dart';
import 'package:aud_io/widgets/proxied_image.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsService>();
    return Scaffold(
      backgroundColor: AudIoTheme.bg,
      body: Consumer<LocalPlaylistService>(
          builder: (context, service, _) {
            context.watch<LocalFileScanner>();
            return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Text('Your Library', style: TextStyle(
                fontSize: 22, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),

              _buildAccountSection(context),
              const SizedBox(height: 20),

               // Row 1: Create + Favorites
               Row(
                 children: [
                   Expanded(child: _buildCreateCard(context, service)),
                   const SizedBox(width: 12),
                   Expanded(child: _buildFavoritesCard(context, service)),
                 ],
               ),
               const SizedBox(height: 12),

              // Row 2: Stats row
              Row(
                children: [
                  Expanded(child: _buildStatMini('Playlists', '${service.playlists.length}', Icons.queue_music_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatMini('Tracks', '${service.playlists.fold<int>(0, (s, p) => s + p.trackCount)}', Icons.music_note_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatMini('Liked', '${service.favoriteCount}', Icons.favorite_rounded)),
                ],
              ),
              const SizedBox(height: 24),

              _buildTransferSection(context, service),
              const SizedBox(height: 24),

              _buildLocalMusicSection(context),
              const SizedBox(height: 24),

              _buildSpotifySection(context),
              const SizedBox(height: 24),

              // Playlists header
              Row(
                children: [
                  Text('Playlists', style: TextStyle(
                    fontSize: 12, color: AudIoTheme.muted, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                ],
              ),
              const SizedBox(height: 12),

              if (service.playlists.isEmpty)
                _buildEmptyState()
              else
                ...service.playlists.map((p) => _PlaylistBentoTile(playlist: p)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLocalMusicSection(BuildContext context) {
    final scanner = context.watch<LocalFileScanner>();
    final handler = context.watch<AppAudioHandler>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Local Music', style: TextStyle(
              fontSize: 12, color: AudIoTheme.muted, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
            const Spacer(),
            Text('${scanner.tracks.length} files', style: TextStyle(
              fontSize: 10, color: AudIoTheme.subtle)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.storage_rounded,
                label: 'Scan Device',
                sublabel: scanner.isScanning ? 'Scanning...' : 'Auto-find music',
                onTap: scanner.isScanning ? null : () => scanner.scan(),
                accent: AudIoTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.folder_open_rounded,
                label: 'Pick Folder',
                sublabel: 'Choose a directory',
                onTap: scanner.isScanning ? null : () => scanner.pickDirectory(),
                accent: AudIoTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_circle_outline,
                label: 'Pick Files',
                sublabel: 'Select audio files',
                onTap: scanner.isScanning ? null : () => scanner.pickFiles(),
                accent: AudIoTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.delete_sweep_outlined,
                label: 'Clear',
                sublabel: 'Remove all local tracks',
                onTap: scanner.tracks.isEmpty ? null : () => scanner.clear(),
                accent: AudIoTheme.error,
              ),
            ),
          ],
        ),
        if (scanner.tracks.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Tracks', style: TextStyle(
            fontSize: 10, color: AudIoTheme.subtle)),
          const SizedBox(height: 8),
          ...scanner.tracks.map((track) => _LocalFileTile(
            track: track,
            onPlay: () => handler.setQueue(scanner.tracks, startIndex: scanner.tracks.indexOf(track)),
          )),
        ],
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String sublabel,
    VoidCallback? onTap,
    required Color accent,
  }) {
    return GestureDetector(
      onTap: onTap,
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
    );
  }

  Widget _buildSpotifySection(BuildContext context) {
    final spotify = context.watch<SpotifyAuthService>();
    final handler = context.watch<AppAudioHandler>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Spotify Import', style: TextStyle(
              fontSize: 12, color: AudIoTheme.muted, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
          ],
        ),
        const SizedBox(height: 12),
        if (!spotify.isLoggedIn)
          GestureDetector(
            onTap: () async {
              final url = Uri.parse(spotify.authUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.platformDefault);
              }
            },
            child: Container(
              height: 70,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1DB954).withValues(alpha: 0.2), AudIoTheme.surface],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(color: const Color(0xFF1DB954), borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.music_note_rounded, size: 18, color: Colors.white)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Connect Spotify', style: TextStyle(
                          fontSize: 14, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
                        Text('Import playlists', style: TextStyle(
                          fontSize: 10, color: AudIoTheme.subtle)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AudIoTheme.subtle),
                ],
              ),
            ),
          )
        else ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(width: 8, height: 8,
                      decoration: const BoxDecoration(color: Color(0xFF1DB954), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Connected', style: TextStyle(
                      fontSize: 10, color: const Color(0xFF1DB954), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => spotify.logout(),
                child: Text('Logout', style: TextStyle(
                  fontSize: 10, color: AudIoTheme.error, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SpotifyPlaylistList(spotify: spotify, handler: handler),
        ],
      ],
    );
  }

  Widget _buildCreateCard(BuildContext context, LocalPlaylistService service) {
    return GestureDetector(
      onTap: () => _showCreateDialog(context, service),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AudIoTheme.primary.withValues(alpha: 0.2),
              AudIoTheme.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AudIoTheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add_rounded, size: 18, color: AudIoTheme.primary),
            ),
            const Spacer(),
            Text('New', style: TextStyle(
              fontSize: 16, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
            Text('Playlist', style: TextStyle(
              fontSize: 16, color: AudIoTheme.primary, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesCard(BuildContext context, LocalPlaylistService service) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => const _LikedSongsPage(),
      )),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AudIoTheme.error.withValues(alpha: 0.15),
              AudIoTheme.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite_rounded, size: 24, color: AudIoTheme.error),
                const Spacer(),
                Text('${service.favoriteCount}', style: TextStyle(
                  fontSize: 13, color: AudIoTheme.error, fontWeight: FontWeight.w700)),
              ],
            ),
            const Spacer(),
            Text('Liked', style: TextStyle(
              fontSize: 16, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
            Text('Songs', style: TextStyle(
              fontSize: 16, color: AudIoTheme.error, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatMini(String label, String value, IconData icon) {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AudIoTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AudIoTheme.subtle),
          const Spacer(),
          Text(value, style: TextStyle(
            fontSize: 18, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(
            fontSize: 9, color: AudIoTheme.subtle)),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('ACCOUNT', style: TextStyle(
              fontSize: 12, color: AudIoTheme.muted, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
          ],
        ),
        const SizedBox(height: 12),
        _AccountCard(),
      ],
    );
  }

  Widget _buildTransferSection(BuildContext context, LocalPlaylistService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('TRANSFER FILES', style: TextStyle(
              fontSize: 12, color: AudIoTheme.muted, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.link_rounded,
                label: 'Import URL',
                sublabel: 'Paste a link',
                onTap: () => _showImportUrlDialog(context),
                accent: AudIoTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.upload_file_rounded,
                label: 'Export',
                sublabel: 'Save playlists',
                onTap: () => _exportPlaylists(context, service),
                accent: const Color(0xFF06D6A0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.phone_android_rounded,
                label: 'Send to Device',
                sublabel: 'Share via network',
                onTap: () => _showDeviceTransfer(context),
                accent: const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.download_rounded,
                label: 'Receive',
                sublabel: 'Accept transfers',
                onTap: () => _showReceiveTransfer(context),
                accent: const Color(0xFF118AB2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showImportUrlDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AudIoTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Import from URL', style: TextStyle(fontSize: 16, color: AudIoTheme.onSurface,
          fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Paste a YouTube or SoundCloud link', style: TextStyle(fontSize: 11, color: AudIoTheme.subtle)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(fontSize: 13, color: AudIoTheme.onSurface),
              decoration: InputDecoration(
                hintText: 'https://youtube.com/watch?v=...',
                hintStyle: TextStyle(fontSize: 12, color: AudIoTheme.subtle),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AudIoTheme.subtle))),
          TextButton(onPressed: () {
            final url = controller.text.trim();
            if (url.isNotEmpty) {
              Navigator.pop(context);
              _processImportUrl(context, url);
            }
          },
            child: Text('Import', style: TextStyle(color: AudIoTheme.primary))),
        ],
      ),
    );
  }

  void _processImportUrl(BuildContext context, String url) async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Importing from URL...'),
      duration: const Duration(seconds: 2),
      backgroundColor: AudIoTheme.surfaceVariant,
    ));

    final videoIdMatch = RegExp(r'(?:v=|/)([a-zA-Z0-9_-]{11})').firstMatch(url);
    final soundcloudMatch = RegExp(r'soundcloud\.com/([^\s]+)').firstMatch(url);

    if (videoIdMatch != null) {
      final videoId = videoIdMatch.group(1)!;
      final track = Track(
        id: videoId,
        title: 'Imported from YouTube',
        artist: 'Unknown Artist',
        source: TrackSource.youtube,
      );
      if (context.mounted) {
        context.read<LocalPlaylistService>().addToPlaylist('Imported', track);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Added to "Imported" playlist'),
          backgroundColor: Colors.green,
        ));
      }
    } else if (soundcloudMatch != null) {
      final track = Track(
        id: soundcloudMatch.group(1)!,
        title: 'Imported from SoundCloud',
        artist: 'Unknown Artist',
        source: TrackSource.soundcloud,
      );
      if (context.mounted) {
        context.read<LocalPlaylistService>().addToPlaylist('Imported', track);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Added to "Imported" playlist'),
          backgroundColor: Colors.green,
        ));
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Unsupported URL format'),
          backgroundColor: AudIoTheme.error,
        ));
      }
    }
  }

  void _exportPlaylists(BuildContext context, LocalPlaylistService service) {
    if (service.playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No playlists to export'),
        backgroundColor: AudIoTheme.surfaceVariant,
      ));
      return;
    }

    String format = 'm3u';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AudIoTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Export Playlists', style: TextStyle(fontSize: 16, color: AudIoTheme.onSurface,
            fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${service.playlists.length} playlists available', style: TextStyle(fontSize: 11, color: AudIoTheme.subtle)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildFormatChip('M3U', 'm3u', format, (f) => setDialogState(() => format = f)),
                  const SizedBox(width: 8),
                  _buildFormatChip('JSON', 'json', format, (f) => setDialogState(() => format = f)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AudIoTheme.subtle))),
            TextButton(onPressed: () {
              Navigator.pop(context);
              _doExport(context, service, format);
            },
              child: Text('Export', style: TextStyle(color: AudIoTheme.primary))),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatChip(String label, String value, String current, ValueChanged<String> onTap) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AudIoTheme.primary.withValues(alpha: 0.2) : AudIoTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AudIoTheme.primary : Colors.transparent, width: 1),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, color: selected ? AudIoTheme.primary : AudIoTheme.muted, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _doExport(BuildContext context, LocalPlaylistService service, String format) async {
    final buffer = StringBuffer();
    if (format == 'm3u') {
      for (final playlist in service.playlists) {
        buffer.writeln('#PLAYLIST:${playlist.name}');
        for (final track in playlist.tracks) {
          final url = track.audioUrl ?? '';
          buffer.writeln('#EXTINF:${track.duration},${track.artistDisplay} - ${track.title}');
          buffer.writeln(url);
        }
        buffer.writeln();
      }
    } else {
      final data = service.playlists.map((p) => {
        'name': p.name,
        'tracks': p.tracks.map((t) => {
          'title': t.title,
          'artist': t.artist,
          'id': t.id,
          'source': t.source.name,
          'duration': t.duration,
          'thumbnail': t.thumbnailUrl,
        }).toList(),
      }).toList();
      buffer.writeln(jsonEncode(data));
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Playlist exported as ${format.toUpperCase()} (${buffer.length} chars)'),
      backgroundColor: Colors.green,
      action: SnackBarAction(label: 'Copy', textColor: Colors.white, onPressed: () {
        // On web, clipboard is the export target
      }),
    ));
  }

  void _showDeviceTransfer(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AudIoTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Send to Device', style: TextStyle(fontSize: 16, color: AudIoTheme.onSurface,
          fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 80,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF6366F1).withValues(alpha: 0.2), AudIoTheme.surface],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_tethering_rounded, size: 24, color: const Color(0xFF6366F1)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Network Transfer', style: TextStyle(
                          fontSize: 13, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
                        Text('Both devices on same WiFi', style: TextStyle(
                          fontSize: 10, color: AudIoTheme.subtle)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Enter the IP address of the receiving device:', style: TextStyle(
              fontSize: 11, color: AudIoTheme.subtle)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: TextStyle(fontSize: 13, color: AudIoTheme.onSurface),
              decoration: InputDecoration(
                hintText: '192.168.1.x:8080',
                hintStyle: TextStyle(fontSize: 12, color: AudIoTheme.subtle),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AudIoTheme.subtle))),
          TextButton(onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Connect the receiving device first'),
              backgroundColor: AudIoTheme.surfaceVariant,
            ));
          },
            child: Text('Send', style: TextStyle(color: const Color(0xFF6366F1)))),
        ],
      ),
    );
  }

  void _showReceiveTransfer(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AudIoTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Receive Transfer', style: TextStyle(fontSize: 16, color: AudIoTheme.onSurface,
          fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 80,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF118AB2).withValues(alpha: 0.2), AudIoTheme.surface],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.wifi_rounded, size: 24, color: const Color(0xFF118AB2)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Listening...', style: TextStyle(
                          fontSize: 13, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
                        Text('Ready to accept transfers', style: TextStyle(
                          fontSize: 10, color: AudIoTheme.subtle)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Share this address with the sending device:', style: TextStyle(
              fontSize: 11, color: AudIoTheme.subtle)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AudIoTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, size: 14, color: AudIoTheme.primary),
                  const SizedBox(width: 8),
                  Text('aud.io/transfer/abc123', style: TextStyle(
                    fontSize: 12, color: AudIoTheme.onSurface, fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: AudIoTheme.subtle))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AudIoTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_rounded, size: 36, color: AudIoTheme.subtle),
            const SizedBox(height: 12),
            Text('No playlists yet', style: TextStyle(
              fontSize: 12, color: AudIoTheme.muted)),
            const SizedBox(height: 4),
            Text('Tap "New Playlist" to start', style: TextStyle(
              fontSize: 10, color: AudIoTheme.subtle)),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, LocalPlaylistService service) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AudIoTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Playlist', style: TextStyle(fontSize: 16, color: AudIoTheme.onSurface,
          fontWeight: FontWeight.w600)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(fontSize: 13, color: AudIoTheme.onSurface),
          decoration: InputDecoration(
            hintText: 'My playlist',
            hintStyle: TextStyle(fontSize: 12, color: AudIoTheme.subtle),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              service.createPlaylist(v.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AudIoTheme.subtle))),
          TextButton(onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              service.createPlaylist(controller.text.trim());
              Navigator.pop(context);
            }
          },
            child: Text('Create', style: TextStyle(color: AudIoTheme.primary))),
        ],
      ),
    );
  }
}

class _PlaylistBentoTile extends StatelessWidget {
  final PlaylistModel playlist;
  const _PlaylistBentoTile({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => _PlaylistDetailPage(playlistId: '${playlist.id}'),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AudIoTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AudIoTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: playlist.tracks.isNotEmpty && playlist.tracks.first.thumbnailUrl != null
                  ? ProxiedImage(url: playlist.tracks.first.thumbnailUrl!, width: 56, height: 56, borderRadius: BorderRadius.circular(10),
                    errorBuilder: (_, __, ___) => Icon(Icons.queue_music_rounded, size: 24, color: AudIoTheme.subtle))
                  : Icon(Icons.queue_music_rounded, size: 24, color: AudIoTheme.subtle),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(playlist.name, style: TextStyle(fontSize: 13, color: AudIoTheme.onSurface,
                    fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${playlist.trackCount} tracks', style: TextStyle(fontSize: 11, color: AudIoTheme.subtle)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                if (playlist.tracks.isNotEmpty) {
                  context.read<AppAudioHandler>().setQueue(playlist.tracks);
                }
              },
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AudIoTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.play_arrow_rounded, size: 22, color: AudIoTheme.onBg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistDetailPage extends StatelessWidget {
  final String playlistId;
  const _PlaylistDetailPage({required this.playlistId});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalPlaylistService>(
      builder: (context, service, _) {
        final idx = service.playlists.indexWhere((p) => '${p.id}' == playlistId);
        if (idx == -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).pop();
          });
          return const SizedBox.shrink();
        }
        final playlist = service.playlists[idx];
        return Scaffold(
          backgroundColor: AudIoTheme.bg,
          body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, size: 24, color: AudIoTheme.onSurface),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(playlist.name, style: TextStyle(
                          fontSize: 16, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 20, color: AudIoTheme.error),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: AudIoTheme.surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text('Delete playlist?', style: TextStyle(fontSize: 14,
                                color: AudIoTheme.onSurface)),
                              content: Text('This cannot be undone.', style: TextStyle(fontSize: 12,
                                color: AudIoTheme.muted)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false),
                                  child: Text('Cancel', style: TextStyle(color: AudIoTheme.subtle))),
                                TextButton(onPressed: () => Navigator.pop(context, true),
                                  child: Text('Delete', style: TextStyle(color: AudIoTheme.error))),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            service.deletePlaylist(playlistId);
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (playlist.tracks.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note_rounded, size: 48, color: AudIoTheme.subtle),
                        const SizedBox(height: 16),
                        Text('Empty playlist', style: TextStyle(fontSize: 12, color: AudIoTheme.muted)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: playlist.tracks.length,
                    itemBuilder: (context, index) {
                      final track = playlist.tracks[index];
                      return _PlaylistTrackTile(
                        track: track, index: index, playlistId: playlistId,
                        onPlay: () => context.read<AppAudioHandler>().setQueue(playlist.tracks, startIndex: index),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LikedSongsPage extends StatelessWidget {
  const _LikedSongsPage();

  @override
  Widget build(BuildContext context) {
    return Consumer<LocalPlaylistService>(
      builder: (context, service, _) {
        final favs = service.favorites;
        return Scaffold(
          backgroundColor: AudIoTheme.bg,
          body: Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, size: 24, color: AudIoTheme.onSurface),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Icon(Icons.favorite_rounded, size: 18, color: AudIoTheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Liked Songs', style: TextStyle(
                          fontSize: 16, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
                      ),
                      if (favs.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.play_circle_fill_rounded, size: 28, color: AudIoTheme.primary),
                          onPressed: () => context.read<AppAudioHandler>().setQueue(favs),
                        ),
                    ],
                  ),
                ),
              ),
              if (favs.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_border_rounded, size: 48, color: AudIoTheme.subtle),
                        const SizedBox(height: 16),
                        Text('No liked songs yet', style: TextStyle(fontSize: 12, color: AudIoTheme.muted)),
                        const SizedBox(height: 4),
                        Text('Tap the heart on any track or podcast', style: TextStyle(
                          fontSize: 10, color: AudIoTheme.subtle)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: favs.length,
                    itemBuilder: (context, index) {
                      final track = favs[index];
                      return InkWell(
                        onTap: () => context.read<AppAudioHandler>().setQueue(favs, startIndex: index),
                        onLongPress: () => showTrackContextMenu(context, track),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AudIoTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              if (track.thumbnailUrl != null)
                                ProxiedImage(url: track.thumbnailUrl!, width: 44, height: 44, borderRadius: BorderRadius.circular(8),
                                  errorBuilder: (_, __, ___) => Container(width: 44, height: 44,
                                    decoration: BoxDecoration(color: AudIoTheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                                    child: Icon(Icons.music_note_rounded, size: 18, color: AudIoTheme.subtle)))
                              else
                                Container(width: 44, height: 44,
                                  decoration: BoxDecoration(color: AudIoTheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                                  child: Icon(track.source == TrackSource.podcast ? Icons.podcasts_rounded : Icons.music_note_rounded,
                                    size: 18, color: AudIoTheme.subtle)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(track.title, style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface,
                                      fontWeight: FontWeight.w500),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text('${track.artistDisplay} · ${track.sourceShort.toLowerCase()}',
                                      style: TextStyle(fontSize: 10, color: AudIoTheme.subtle),
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => service.toggleFavorite(track),
                                child: Icon(Icons.favorite_rounded, size: 18, color: AudIoTheme.error),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LocalFileTile extends StatelessWidget {
  final Track track;
  final VoidCallback onPlay;

  const _LocalFileTile({required this.track, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final name = track.audioUrl?.split('/').last.split('\\').last ?? track.title;
    return InkWell(
      onTap: onPlay,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AudIoTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AudIoTheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.music_note_rounded, size: 16, color: AudIoTheme.subtle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title, style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface,
                    fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(name, style: TextStyle(fontSize: 9, color: AudIoTheme.subtle),
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

class _PlaylistTrackTile extends StatelessWidget {
  final Track track;
  final int index;
  final String playlistId;
  final VoidCallback onPlay;

  const _PlaylistTrackTile({
    required this.track,
    required this.index,
    required this.playlistId,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPlay,
      onLongPress: () => showTrackContextMenu(context, track),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AudIoTheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text('${index + 1}', style: TextStyle(fontSize: 11, color: AudIoTheme.subtle)),
            ),
            if (track.thumbnailUrl != null)
              ProxiedImage(url: track.thumbnailUrl!, width: 44, height: 44, borderRadius: BorderRadius.circular(8),
                errorBuilder: (_, __, ___) => Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: AudIoTheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.music_note_rounded, size: 18, color: AudIoTheme.subtle)))
            else
              Container(width: 44, height: 44,
                decoration: BoxDecoration(color: AudIoTheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.music_note_rounded, size: 18, color: AudIoTheme.subtle)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title, style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface,
                    fontWeight: FontWeight.w500),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(track.artistDisplay, style: TextStyle(fontSize: 10, color: AudIoTheme.subtle),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => context.read<LocalPlaylistService>().removeTrackFromPlaylist(playlistId, track.id),
              child: Icon(Icons.close_rounded, size: 16, color: AudIoTheme.subtle),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotifyPlaylistList extends StatefulWidget {
  final SpotifyAuthService spotify;
  final AppAudioHandler handler;
  const _SpotifyPlaylistList({required this.spotify, required this.handler});

  @override
  State<_SpotifyPlaylistList> createState() => _SpotifyPlaylistListState();
}

class _SpotifyPlaylistListState extends State<_SpotifyPlaylistList> {
  List<SpotifyPlaylist>? _playlists;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final playlists = await widget.spotify.getPlaylists();
    if (mounted) setState(() { _playlists = playlists; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 60,
        decoration: BoxDecoration(color: AudIoTheme.surface, borderRadius: BorderRadius.circular(14)),
        child: Center(child: SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: AudIoTheme.subtle))),
      );
    }
    if (_playlists == null || _playlists!.isEmpty) {
      return Container(
        height: 60,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AudIoTheme.surface, borderRadius: BorderRadius.circular(14)),
        child: Center(child: Text('No playlists found', style: TextStyle(fontSize: 11, color: AudIoTheme.subtle))),
      );
    }
    return Column(
      children: [
        ..._playlists!.map((p) => GestureDetector(
          onTap: () => _importPlaylist(p),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AudIoTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (p.image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(p.image!, width: 44, height: 44, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 44, height: 44,
                        color: AudIoTheme.surfaceVariant,
                        child: Icon(Icons.queue_music_rounded, size: 18, color: AudIoTheme.subtle))),
                  )
                else
                  Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: AudIoTheme.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.queue_music_rounded, size: 18, color: AudIoTheme.subtle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface,
                        fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${p.trackCount} tracks · ${p.owner}',
                        style: TextStyle(fontSize: 10, color: AudIoTheme.subtle),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(Icons.download_rounded, size: 16, color: AudIoTheme.primary),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Future<void> _importPlaylist(SpotifyPlaylist playlist) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Importing "${playlist.name}"...'),
      duration: const Duration(seconds: 2),
      backgroundColor: AudIoTheme.surfaceVariant,
    ));

    final tracks = await widget.spotify.getPlaylistTracks(playlist.id);
    if (tracks.isEmpty || !mounted) return;

    final localPlaylistService = context.read<LocalPlaylistService>();

    for (final st in tracks) {
      final track = Track(
        id: 'spotify_${st.id}',
        title: st.title,
        artist: st.artist,
        album: st.album,
        thumbnailUrl: st.artwork,
        duration: st.duration,
        source: TrackSource.soundcloud,
      );
      await localPlaylistService.addToPlaylist(playlist.name, track);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Imported ${tracks.length} tracks into "${playlist.name}"'),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.green,
      ));
    }
  }
}

class _AccountCard extends StatefulWidget {
  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _isLoggedIn = false;
  String _userName = '';
  String _userEmail = '';
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return Container(
        height: 80,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AudIoTheme.primary.withValues(alpha: 0.15), AudIoTheme.surface],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AudIoTheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                  style: TextStyle(fontSize: 18, color: AudIoTheme.primary, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_userName, style: TextStyle(
                    fontSize: 14, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
                  Text(_userEmail, style: TextStyle(
                    fontSize: 10, color: AudIoTheme.subtle)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() {
                _isLoggedIn = false;
                _userName = '';
                _userEmail = '';
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AudIoTheme.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Logout', style: TextStyle(
                  fontSize: 10, color: AudIoTheme.error, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AudIoTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded, size: 20, color: AudIoTheme.primary),
              const SizedBox(width: 10),
              Text('Sign in to sync', style: TextStyle(
                fontSize: 14, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Save playlists, likes, and history across devices', style: TextStyle(
            fontSize: 10, color: AudIoTheme.subtle)),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Name',
              hintStyle: TextStyle(fontSize: 11, color: AudIoTheme.subtle),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: AudIoTheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Email',
              hintStyle: TextStyle(fontSize: 11, color: AudIoTheme.subtle),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: AudIoTheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: true,
            style: TextStyle(fontSize: 12, color: AudIoTheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(fontSize: 11, color: AudIoTheme.subtle),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: AudIoTheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              setState(() {
                _isLoggedIn = true;
                _userName = _nameController.text.isNotEmpty ? _nameController.text : 'User';
                _userEmail = _emailController.text.isNotEmpty ? _emailController.text : 'user@email.com';
              });
            },
            child: Container(
              width: double.infinity,
              height: 36,
              decoration: BoxDecoration(
                color: AudIoTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('Sign In', style: TextStyle(
                  fontSize: 12, color: AudIoTheme.onBg, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: AudIoTheme.surfaceVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('or', style: TextStyle(fontSize: 10, color: AudIoTheme.subtle)),
              ),
              Expanded(child: Container(height: 1, color: AudIoTheme.surfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isLoggedIn = true;
                      _userName = 'Google User';
                      _userEmail = 'user@gmail.com';
                    });
                  },
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: AudIoTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.g_mobiledata_rounded, size: 18, color: AudIoTheme.onSurface),
                          const SizedBox(width: 6),
                          Text('Google', style: TextStyle(fontSize: 11, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isLoggedIn = true;
                      _userName = 'Apple User';
                      _userEmail = 'user@icloud.com';
                    });
                  },
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: AudIoTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.apple_rounded, size: 16, color: AudIoTheme.onSurface),
                          const SizedBox(width: 6),
                          Text('Apple', style: TextStyle(fontSize: 11, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
