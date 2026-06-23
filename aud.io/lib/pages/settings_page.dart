import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/core/theme/theme_presets.dart';
import 'package:aud_io/services/settings_service.dart';
import 'package:aud_io/services/download_service.dart';
import 'package:aud_io/services/local_playlist_service.dart';
import 'package:aud_io/services/youtube_music_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsService>();
    return Scaffold(
      backgroundColor: AudIoTheme.bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text('Settings', style: TextStyle(
            fontSize: 22, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          _buildThemePicker(context),
          const SizedBox(height: 12),

          // Row 1: Quality (full width - theme removed, always dark)
          _buildQualityCard(context),
          const SizedBox(height: 12),

          // Row 2: Offline + Auto-download
          Row(
            children: [
              Expanded(child: _buildOfflineCard(context)),
              const SizedBox(width: 12),
              Expanded(child: _buildAutoDownloadCard(context)),
            ],
          ),
          const SizedBox(height: 12),

          // Row 3: Storage (wide) + About (small)
          Row(
            children: [
              Expanded(flex: 3, child: _buildStorageCard(context)),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _buildAboutCard()),
            ],
          ),
          const SizedBox(height: 12),

          // Row 4: Library data management
          _buildLibraryCard(context),
          const SizedBox(height: 12),

          // Row 5: Source availability
          const _SourcesCard(),
        ],
      ),
    );
  }

  Widget _buildThemePicker(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final currentId = settings.themeId;
    final darkThemes = ThemePresets.all.where((p) => p.brightness == Brightness.dark).toList();
    final lightThemes = ThemePresets.all.where((p) => p.brightness == Brightness.light).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('THEME', style: TextStyle(
          fontSize: 12, color: AudIoTheme.muted, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Text('Dark', style: TextStyle(fontSize: 10, color: AudIoTheme.subtle, letterSpacing: 1)),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: darkThemes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final p = darkThemes[i];
              final selected = p.id == currentId;
              return GestureDetector(
                onTap: () => settings.setThemeId(p.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 90,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? p.primary.withValues(alpha: 0.2) : AudIoTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? p.primary : AudIoTheme.surfaceVariant,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(width: 12, height: 12,
                            decoration: BoxDecoration(color: p.preview, borderRadius: BorderRadius.circular(6)),
                          ),
                          const SizedBox(width: 6),
                          if (selected) Icon(Icons.check_rounded, size: 12, color: p.primary)
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(p.name, style: TextStyle(
                        fontSize: 10, color: selected ? AudIoTheme.onSurface : AudIoTheme.muted,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text('Light', style: TextStyle(fontSize: 10, color: AudIoTheme.subtle, letterSpacing: 1)),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: lightThemes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final p = lightThemes[i];
              final selected = p.id == currentId;
              return GestureDetector(
                onTap: () => settings.setThemeId(p.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 90,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? p.primary.withValues(alpha: 0.2) : AudIoTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? p.primary : AudIoTheme.surfaceVariant,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(width: 12, height: 12,
                            decoration: BoxDecoration(color: p.preview, borderRadius: BorderRadius.circular(6)),
                          ),
                          const SizedBox(width: 6),
                          if (selected) Icon(Icons.check_rounded, size: 12, color: p.primary),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(p.name, style: TextStyle(
                        fontSize: 10, color: selected ? AudIoTheme.onSurface : AudIoTheme.muted,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryCard(BuildContext context) {
    return Consumer<LocalPlaylistService>(
      builder: (_, lib, _) {
        final trackTotal = lib.playlists.fold<int>(0, (s, p) => s + p.trackCount);
        return _BentoCard(
          height: 92,
          gradient: [AudIoTheme.surface, AudIoTheme.surfaceVariant],
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AudIoTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.library_music_rounded, size: 20, color: AudIoTheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Library', style: TextStyle(
                      fontSize: 13, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
                    Text('${lib.playlists.length} playlists · $trackTotal tracks · ${lib.favoriteCount} liked',
                      style: TextStyle(fontSize: 10, color: AudIoTheme.subtle),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _clearLibrary(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AudIoTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Reset', style: TextStyle(fontSize: 10, color: AudIoTheme.error)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _clearLibrary(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AudIoTheme.surface,
        title: Text('Reset library?', style: TextStyle(fontSize: 14, color: AudIoTheme.onSurface)),
        content: Text('This removes all playlists and liked songs. Downloads are kept.',
          style: TextStyle(fontSize: 12, color: AudIoTheme.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AudIoTheme.subtle))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: Text('Reset', style: TextStyle(color: AudIoTheme.error))),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final lib = context.read<LocalPlaylistService>();
      for (final p in List.of(lib.playlists)) {
        lib.deletePlaylist('${p.id}');
      }
      for (final t in List.of(lib.favorites)) {
        lib.toggleFavorite(t);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Library reset')));
      }
    }
  }

  // TODO: re-enable this when theme selection is needed
  // ignore: unused_element
  Widget _buildQualityCard(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (_, s, _) => _BentoCard(
        height: 130,
        gradient: [AudIoTheme.surface, AudIoTheme.surfaceVariant],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.high_quality_rounded, size: 20, color: AudIoTheme.primary),
            const Spacer(),
            Text('Quality', style: TextStyle(
              fontSize: 14, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
            DropdownButton<String>(
              value: s.audioQuality,
              isDense: true,
              dropdownColor: AudIoTheme.surfaceVariant,
              style: TextStyle(fontSize: 10, color: AudIoTheme.subtle),
              underline: const SizedBox(),
              items: ['128', '192', '256', '320'].map((q) => DropdownMenuItem(
                value: q, child: Text('$q kbps'))).toList(),
              onChanged: (v) => v != null ? s.setAudioQuality(v) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineCard(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (_, s, _) => _BentoCard(
        height: 130,
        gradient: [AudIoTheme.surface, AudIoTheme.surfaceVariant],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi_off_rounded, size: 20, color: AudIoTheme.primary),
                const Spacer(),
                Switch(
                  value: s.offlineMode,
                  onChanged: s.setOfflineMode,
                  activeThumbColor: AudIoTheme.primary,
                ),
              ],
            ),
            const Spacer(),
            Text('Offline', style: TextStyle(
              fontSize: 14, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
            Text('Download only', style: TextStyle(
              fontSize: 10, color: AudIoTheme.subtle)),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoDownloadCard(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (_, s, _) => _BentoCard(
        height: 130,
        gradient: [AudIoTheme.surface, AudIoTheme.surfaceVariant],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.download_rounded, size: 20, color: AudIoTheme.primary),
                const Spacer(),
                Switch(
                  value: s.autoDownload,
                  onChanged: s.setAutoDownload,
                  activeThumbColor: AudIoTheme.primary,
                ),
              ],
            ),
            const Spacer(),
            Text('Auto DL', style: TextStyle(
              fontSize: 14, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
            Text('On WiFi', style: TextStyle(
              fontSize: 10, color: AudIoTheme.subtle)),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageCard(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (_, s, _) => _BentoCard(
        height: 140,
        gradient: [AudIoTheme.surface, AudIoTheme.surfaceVariant],
        onTap: () => _pickDownloadDirectory(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_rounded, size: 20, color: AudIoTheme.primary),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 18, color: AudIoTheme.subtle),
              ],
            ),
            const Spacer(),
            Text('Storage', style: TextStyle(
              fontSize: 14, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(s.downloadDir ?? 'Default', style: TextStyle(
              fontSize: 10, color: AudIoTheme.subtle),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _clearCache(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AudIoTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Clear cache', style: TextStyle(
                  fontSize: 9, color: AudIoTheme.error)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return _BentoCard(
      height: 140,
      gradient: [AudIoTheme.surface, AudIoTheme.surfaceVariant],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: AudIoTheme.subtle),
          const Spacer(),
          Text('aud.io', style: TextStyle(
            fontSize: 14, color: AudIoTheme.onSurface, fontWeight: FontWeight.w700)),
          Text('v1.0.0-beta', style: TextStyle(
            fontSize: 10, color: AudIoTheme.subtle)),
        ],
      ),
    );
  }

  Future<void> _pickDownloadDirectory(BuildContext context) async {
    final settings = context.read<SettingsService>();
    final result = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select Download Directory');
    if (result != null) {
      await settings.setDownloadDir(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download directory updated', style: TextStyle())));
      }
    }
  }

  Future<void> _clearCache(BuildContext context) async {
    final svc = context.read<DownloadService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AudIoTheme.surface,
        title: Text('Clear Downloads?', style: TextStyle(fontSize: 14, color: AudIoTheme.onSurface)),
        content: Text('This will delete all downloaded files.', style: TextStyle(fontSize: 12,
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
      await svc.clearAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloads cleared')));
      }
    }
  }
}

class _SourcesCard extends StatelessWidget {
  const _SourcesCard();

  @override
  Widget build(BuildContext context) {
    final ytOn = YouTubeMusicService.isAvailable;
    final podKey = const String.fromEnvironment('PODCAST_INDEX_API_KEY');
    final podOn = podKey.isNotEmpty;
    final scEnv = const String.fromEnvironment('SOUNDCLOUD_CLIENT_ID');
    final scOn = scEnv.isNotEmpty;

    final sources = <_SourceBadge>[
      _SourceBadge('YouTube', ytOn, Icons.play_circle_rounded),
      _SourceBadge('SoundCloud', scOn || true, Icons.cloud_rounded),
      _SourceBadge('Podcasts', podOn, Icons.podcasts_rounded),
    ];

    return _BentoCard(
      height: 110,
      gradient: [AudIoTheme.primary.withValues(alpha: 0.08), AudIoTheme.surface],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_rounded, size: 16, color: AudIoTheme.primary),
              const SizedBox(width: 6),
              Text('SOURCES', style: TextStyle(
                fontSize: 10, color: AudIoTheme.muted, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: sources
                .map((s) => _SourcePill(badge: s))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SourceBadge {
  final String label;
  final bool on;
  final IconData icon;
  _SourceBadge(this.label, this.on, this.icon);
}

class _SourcePill extends StatelessWidget {
  final _SourceBadge badge;
  const _SourcePill({required this.badge});

  @override
  Widget build(BuildContext context) {
    final color = badge.on ? AudIoTheme.primary : AudIoTheme.subtle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(badge.icon, size: 16, color: color),
        ),
        const SizedBox(height: 6),
        Text(badge.label, style: TextStyle(
          fontSize: 9, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(badge.on ? 'ready' : 'limited', style: TextStyle(
          fontSize: 8, color: color)),
      ],
    );
  }
}

class _BentoCard extends StatelessWidget {
  final double height;
  final List<Color> gradient;
  final Widget child;
  final VoidCallback? onTap;

  const _BentoCard({
    required this.height,
    required this.gradient,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      ),
    );
  }
}


