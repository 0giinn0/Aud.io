import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aud_io/core/models/track.dart';

const _audioExtensions = {'.mp3', '.flac', '.wav', '.aac', '.ogg', '.m4a', '.wma', '.opus', '.aiff', '.alac'};

class LocalFileScanner extends ChangeNotifier {
  final List<Track> _tracks = [];
  bool _isScanning = false;
  String _lastScanPath = '';

  List<Track> get tracks => List.unmodifiable(_tracks);
  bool get isScanning => _isScanning;
  String get lastScanPath => _lastScanPath;

  bool isAudioFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return _audioExtensions.contains('.$ext');
  }

  Future<void> scan() async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    try {
      if (!kIsWeb) {
        final status = await Permission.storage.request();
        if (status.isGranted || status.isLimited) {
          if (Platform.isAndroid) {
            await _scanAndroid();
          } else if (Platform.isIOS) {
            await _scanIOS();
          } else {
            await _scanDesktop();
          }
        }
      }
    } catch (_) {}

    _isScanning = false;
    notifyListeners();
  }

  Future<void> pickDirectory() async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        _lastScanPath = result;
        await _scanDirectory(Directory(result));
      }
    } catch (_) {}

    _isScanning = false;
    notifyListeners();
  }

  Future<void> pickFiles() async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'flac', 'wav', 'aac', 'ogg', 'm4a', 'wma', 'opus', 'aiff', 'alac'],
        allowMultiple: true,
      );
      if (result != null) {
        for (final f in result.files) {
          if (f.path != null) {
            _addTrack(f.path!);
          }
        }
      }
    } catch (_) {}

    _isScanning = false;
    notifyListeners();
  }

  Future<void> _scanAndroid() async {
    final dirs = <String>[
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Audio',
      '/storage/emulated/0/Movies',
      '/storage/emulated/0/Recordings',
      '/sdcard/Music',
      '/sdcard/Download',
    ];

    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        _lastScanPath = dirPath;
        await _scanDirectory(dir);
      }
    }
  }

  Future<void> _scanIOS() async {
    final appDir = await getApplicationDocumentsDirectory();
    _lastScanPath = appDir.path;
    await _scanDirectory(appDir);

    final libDir = await getLibraryDirectory();
    final musicDir = Directory('${libDir.path}/Music');
    if (await musicDir.exists()) {
      await _scanDirectory(musicDir);
    }
  }

  Future<void> _scanDesktop() async {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
    if (home.isEmpty) return;

    final dirs = [
      '$home/Music',
      '$home/Downloads',
      '$home/Desktop',
    ];

    for (final dirPath in dirs) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        _lastScanPath = dirPath;
        await _scanDirectory(dir);
      }
    }
  }

  Future<void> _scanDirectory(Directory dir, {int depth = 0}) async {
    if (depth > 4) return;

    try {
      final entities = dir.listSync(followLinks: false);
      for (final entity in entities) {
        if (entity is File && isAudioFile(entity.path)) {
          _addTrack(entity.path);
        } else if (entity is Directory && depth < 4) {
          await _scanDirectory(entity, depth: depth + 1);
        }
      }
    } catch (_) {}
  }

  void _addTrack(String path) {
    if (_tracks.any((t) => t.audioUrl == path)) return;
    _tracks.add(Track.fromLocalFile(path));
    notifyListeners();
  }

  void clear() {
    _tracks.clear();
    _lastScanPath = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _tracks.clear();
    super.dispose();
  }
}
