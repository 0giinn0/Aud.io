import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aud_io/core/theme/aud_io_theme.dart';
import 'package:aud_io/services/settings_service.dart';
import 'package:aud_io/services/download_service.dart';

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

          // Row 1: Theme + Quality
          Row(
            children: [
              Expanded(child: _buildThemeCard(context)),
              const SizedBox(width: 12),
              Expanded(child: _buildQualityCard(context)),
            ],
          ),
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

          // Row 4: Server status
          _buildServerCard(),
        ],
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (_, s, __) => _BentoCard(
        height: 130,
        gradient: [AudIoTheme.surface, AudIoTheme.surfaceVariant],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(s.lightMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 20, color: AudIoTheme.primary),
                const Spacer(),
                Switch(
                  value: !s.lightMode,
                  onChanged: (v) => s.setLightMode(!v),
                  activeColor: AudIoTheme.primary,
                ),
              ],
            ),
            const Spacer(),
            Text('Theme', style: TextStyle(
              fontSize: 14, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
            Text(s.lightMode ? 'Light mode' : 'Dark mode', style: TextStyle(
              fontSize: 10, color: AudIoTheme.subtle)),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityCard(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (_, s, __) => _BentoCard(
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
      builder: (_, s, __) => _BentoCard(
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
                  activeColor: AudIoTheme.primary,
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
      builder: (_, s, __) => _BentoCard(
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
                  activeColor: AudIoTheme.primary,
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
      builder: (_, s, __) => _BentoCard(
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

  Widget _buildServerCard() {
    return _BentoCard(
      height: 80,
      gradient: [AudIoTheme.primary.withValues(alpha: 0.08), AudIoTheme.surface],
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AudIoTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.dns_rounded, size: 20, color: AudIoTheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Server', style: TextStyle(
                  fontSize: 13, color: AudIoTheme.onSurface, fontWeight: FontWeight.w600)),
                Text('localhost:3001', style: TextStyle(
                  fontSize: 10, color: AudIoTheme.subtle)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AudIoTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AudIoTheme.primary)),
                const SizedBox(width: 6),
                Text('Active', style: TextStyle(
                  fontSize: 10, color: AudIoTheme.primary)),
              ],
            ),
          ),
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
      await context.read<DownloadService>().clearAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloads cleared', style: TextStyle())));
      }
    }
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
