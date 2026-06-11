import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:aud_io/core/models/track.dart';

class LocalFileScanner extends ChangeNotifier {
  List<Track> _localTracks = [];
  bool _isScanning = false;
  String _scanStatus = '';

  List<Track> get localTracks => List.unmodifiable(_localTracks);
  bool get isScanning => _isScanning;
  String get scanStatus => _scanStatus;

  Future<void> scanDevice() async {
    if (_isScanning) return;
    _isScanning = true;
    _scanStatus = 'requesting permissions...';
    notifyListeners();

    try {
      if (!kIsWeb) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          _scanStatus = 'storage permission denied';
          _isScanning = false;
          notifyListeners();
          return;
        }
      }

      _scanStatus = 'finding music directories...';
      notifyListeners();

      final directories = await _getMusicDirectories();
      _scanStatus = 'scanning ${directories.length} directories...';
      notifyListeners();

      final tracks = <Track>[];
      int scanned = 0;

      for (final dir in directories) {
        _scanStatus = 'scanning ${dir.path.split('/').last}... ($scanned found)';
        notifyListeners();
        final dirTracks = await _scanDirectory(dir);
        tracks.addAll(dirTracks);
        scanned += dirTracks.length;
      }

      _localTracks = tracks;
      _scanStatus = 'found ${tracks.length} tracks';
      notifyListeners();
    } catch (e) {
      _scanStatus = 'error: $e';
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<List<Directory>> _getMusicDirectories() async {
    final dirs = <Directory>[];

    if (!kIsWeb) {
      // Android standard music directories
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        dirs.add(Directory('${externalDir.path}/Music'));
        dirs.add(Directory('${externalDir.path}/Download'));
      }

      // Common music folders
      final homeDir = await getApplicationDocumentsDirectory();
      dirs.add(Directory('${homeDir.path}/Music'));

      // Try to get external storage root
      try {
        final rootDirs = [
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Download',
          '/sdcard/Music',
          '/sdcard/Download',
        ];
        for (final path in rootDirs) {
          final dir = Directory(path);
          if (await dir.exists()) dirs.add(dir);
        }
      } catch (_) {}
    }

    // Remove duplicates and non-existent
    final unique = <Directory>[];
    final seen = <String>{};
    for (final dir in dirs) {
      final absPath = dir.absolute.path;
      if (!seen.contains(absPath) && await dir.exists()) {
        seen.add(absPath);
        unique.add(dir);
      }
    }
    return unique;
  }

  Future<List<Track>> _scanDirectory(Directory dir) async {
    final tracks = <Track>[];
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = entity.path.toLowerCase().split('.').last;
          if (ext == 'mp3' || ext == 'flac' || ext == 'm4a' || ext == 'ogg' || ext == 'wav') {
            tracks.add(Track.fromLocalFile(entity));
          }
        }
      }
    } catch (_) {}
    return tracks;
  }

  void addUploadedTrack(Track track) {
    _localTracks = [track, ..._localTracks];
    notifyListeners();
  }

  void clear() {
    _localTracks.clear();
    notifyListeners();
  }
}