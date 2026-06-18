import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const _kOfflineMode = 'offline_mode';
  static const _kCustomDisplayPath = 'custom_display_path';
  static const _kAudioQuality = 'audio_quality';
  static const _kAutoDownload = 'auto_download';
  static const _kThemeId = 'theme_id';
  static const _kDownloadDir = 'download_dir';

  bool _offlineMode = false;
  String? _customDisplayPath;
  String _audioQuality = '192';
  bool _autoDownload = false;
  String _themeId = 'ink_red';
  String? _downloadDir;
  bool _initialized = false;

  bool get offlineMode => _offlineMode;
  String? get customDisplayPath => _customDisplayPath;
  String get audioQuality => _audioQuality;
  bool get autoDownload => _autoDownload;
  String get themeId => _themeId;
  String? get downloadDir => _downloadDir;
  bool get initialized => _initialized;
  bool get lightMode => !_isDarkTheme(_themeId);

  bool _isDarkTheme(String id) {
    return id != 'cream_red' && id != 'pure_white' && id != 'warm_sand';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _offlineMode = prefs.getBool(_kOfflineMode) ?? false;
    _customDisplayPath = prefs.getString(_kCustomDisplayPath);
    _audioQuality = prefs.getString(_kAudioQuality) ?? '192';
    _autoDownload = prefs.getBool(_kAutoDownload) ?? false;
    _themeId = prefs.getString(_kThemeId) ?? 'ink_red';
    _downloadDir = prefs.getString(_kDownloadDir);
    _initialized = true;
    notifyListeners();
  }

  void initSync() {
    init();
  }

  Future<void> setOfflineMode(bool value) async {
    _offlineMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOfflineMode, value);
    notifyListeners();
  }

  Future<void> setCustomDisplayPath(String? path) async {
    _customDisplayPath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString(_kCustomDisplayPath, path);
    } else {
      await prefs.remove(_kCustomDisplayPath);
    }
    notifyListeners();
  }

  Future<void> setAudioQuality(String quality) async {
    _audioQuality = quality;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAudioQuality, quality);
    notifyListeners();
  }

  Future<void> setAutoDownload(bool value) async {
    _autoDownload = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoDownload, value);
    notifyListeners();
  }

  Future<void> setThemeId(String id) async {
    _themeId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeId, id);
    notifyListeners();
  }

  Future<void> setDownloadDir(String? path) async {
    _downloadDir = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString(_kDownloadDir, path);
    } else {
      await prefs.remove(_kDownloadDir);
    }
    notifyListeners();
  }

  void reset() {
    _offlineMode = false;
    _customDisplayPath = null;
    _audioQuality = '192';
    _autoDownload = false;
    _themeId = 'ink_red';
    _downloadDir = null;
    notifyListeners();
  }
}