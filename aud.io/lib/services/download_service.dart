import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:aud_io/core/models/track.dart';

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Map<String, DownloadTask> _tasks = {};
  final Map<String, String> _localFiles = {};
  Directory? _downloadDir;

  Map<String, DownloadTask> get tasks => Map.unmodifiable(_tasks);
  Map<String, String> get localFiles => Map.unmodifiable(_localFiles);

  Future<void> init() async {
    if (!kIsWeb) {
      final appDir = await getApplicationDocumentsDirectory();
      _downloadDir = Directory('${appDir.path}/aud.io_downloads');
      if (!await _downloadDir!.exists()) {
        await _downloadDir!.create(recursive: true);
      }
      await _scanExistingFiles();
    }
    notifyListeners();
  }

  Future<void> _scanExistingFiles() async {
    if (_downloadDir == null) return;
    try {
      final files = _downloadDir!.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith('.mp3')) {
          final id = file.path.split('/').last.replaceAll('.mp3', '');
          _localFiles[id] = file.path;
        }
      }
    } catch (_) {}
  }

  bool isDownloaded(String id) => _localFiles.containsKey(id);

  String? getLocalPath(String id) => _localFiles[id];

  Future<void> downloadTrack(String id, TrackSource source) async {
    if (_tasks.containsKey(id)) return;
    if (isDownloaded(id)) return;

    final task = DownloadTask(id: id, source: source, status: DownloadStatus.downloading, progress: 0.0);
    _tasks[id] = task;
    notifyListeners();

    try {
      const baseUrl = 'http://localhost:3001';
      final response = await http.post(
        Uri.parse('$baseUrl/api/download'),
        headers: {'Content-Type': 'application/json'},
        body: '{"id":"$id","source":"${source == TrackSource.soundcloud ? "soundcloud" : "youtube"}"}',
      ).timeout(const Duration(minutes: 3));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      if (response.body.contains('"cached":true')) {
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        if (!kIsWeb) {
          final localPath = '${_downloadDir!.path}/$id.mp3';
          _localFiles[id] = localPath;
        }
        notifyListeners();
        return;
      }

      final fileUrl = '$baseUrl/api/download/$id';
      final req = http.Request('GET', Uri.parse(fileUrl));
      final streamed = await http.Client().send(req);
      final totalBytes = streamed.contentLength ?? 0;
      int receivedBytes = 0;

      if (!kIsWeb && _downloadDir != null) {
        final file = File('${_downloadDir!.path}/$id.mp3');
        final sink = file.openWrite();
        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          task.progress = totalBytes > 0 ? receivedBytes / totalBytes : 0.5;
          notifyListeners();
        }
        await sink.close();
        _localFiles[id] = file.path;
      }

      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      notifyListeners();
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteTrack(String id) async {
    if (!isDownloaded(id)) return;
    try {
      if (!kIsWeb && _downloadDir != null) {
        final file = File(_localFiles[id]!);
        if (await file.exists()) await file.delete();
      }
      _localFiles.remove(id);
      notifyListeners();
    } catch (_) {}
  }

  void clearError(String id) {
    if (_tasks.containsKey(id)) {
      _tasks[id]!.error = null;
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    if (!kIsWeb && _downloadDir != null) {
      try {
        final files = _downloadDir!.listSync();
        for (final file in files) {
          if (file is File && file.path.endsWith('.mp3')) {
            await file.delete();
          }
        }
      } catch (_) {}
    }
    _localFiles.clear();
    _tasks.clear();
    notifyListeners();
  }
}

class DownloadTask {
  final String id;
  final TrackSource source;
  DownloadStatus status;
  double progress;
  String? error;

  DownloadTask({
    required this.id,
    required this.source,
    required this.status,
    required this.progress,
    this.error,
  });
}

enum DownloadStatus { idle, downloading, completed, failed }