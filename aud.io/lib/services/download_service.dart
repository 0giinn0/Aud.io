import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/api_service.dart';
import 'download_platform.dart' if (dart.library.html) 'download_platform_web.dart';

// Notification callback type
typedef DownloadNotificationCallback = void Function(DownloadNotification notification);

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Map<String, DownloadTask> _tasks = {};
  final Map<String, String> _localFiles = {};
  Directory? _downloadDir;
  DownloadNotificationCallback? _notificationCallback;

  Map<String, DownloadTask> get tasks => Map.unmodifiable(_tasks);
  Map<String, String> get localFiles => Map.unmodifiable(_localFiles);

  void setNotificationCallback(DownloadNotificationCallback callback) {
    _notificationCallback = callback;
  }

  void _notify(DownloadNotification notification) {
    _notificationCallback?.call(notification);
  }

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
        if (file is File && (file.path.endsWith('.mp3') || file.path.endsWith('.opus') || file.path.endsWith('.m4a'))) {
          final id = file.path.split('/').last.replaceAll(RegExp(r'\.(mp3|opus|m4a)$'), '');
          _localFiles[id] = file.path;
        }
      }
    } catch (_) {}
  }

  bool isDownloaded(String id) => _localFiles.containsKey(id);

  String? getLocalPath(String id) => _localFiles[id];

  /// Download a YouTube/SoundCloud track
  Future<void> downloadTrack(String id, TrackSource source, {String? trackTitle}) async {
    if (_tasks.containsKey(id)) return;
    if (isDownloaded(id)) return;

    final task = DownloadTask(id: id, source: source, status: DownloadStatus.downloading, progress: 0.0, title: trackTitle);
    _tasks[id] = task;
    _notify(DownloadNotification(id: id, type: DownloadNotificationType.started, title: trackTitle ?? 'Download starting', progress: 0.0));
    notifyListeners();

    try {
      final baseUrl = ApiService.baseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/api/download'),
        headers: {'Content-Type': 'application/json'},
        body: '{"id":"$id","source":"${source == TrackSource.soundcloud ? "soundcloud" : "youtube"}"}',
      ).timeout(const Duration(minutes: 3));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final fileUrl = '$baseUrl/api/download/$id';

      if (kIsWeb) {
        // Web: open download URL in new tab to trigger browser's native download
        triggerDownload(fileUrl, trackTitle ?? id);
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        _notify(DownloadNotification(id: id, type: DownloadNotificationType.completed, title: trackTitle ?? 'Download complete', progress: 1.0));
        notifyListeners();
        return;
      }

      // Mobile: stream to local file
      final req = http.Request('GET', Uri.parse(fileUrl));
      final streamed = await http.Client().send(req);
      final totalBytes = streamed.contentLength ?? 0;
      int receivedBytes = 0;

      if (_downloadDir != null) {
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
      _notify(DownloadNotification(id: id, type: DownloadNotificationType.completed, title: trackTitle ?? 'Download complete', progress: 1.0));
      notifyListeners();
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString();
      _notify(DownloadNotification(id: id, type: DownloadNotificationType.failed, title: trackTitle ?? 'Download failed', error: e.toString(), progress: 0.0));
      notifyListeners();
    }
  }

  /// Download a podcast episode directly from its audio URL
  Future<void> downloadPodcastEpisode(String episodeId, String audioUrl, {String? title, String? thumbnailUrl}) async {
    if (_tasks.containsKey(episodeId)) return;
    if (isDownloaded(episodeId)) return;

    final task = DownloadTask(id: episodeId, source: TrackSource.podcast, status: DownloadStatus.downloading, progress: 0.0, title: title);
    _tasks[episodeId] = task;
    _notify(DownloadNotification(id: episodeId, type: DownloadNotificationType.started, title: title ?? 'Download starting', progress: 0.0));
    notifyListeners();

    try {
      if (kIsWeb) {
        // Web: trigger browser download of the audio URL directly
        triggerDownload(ApiService.proxyDirectUrl(audioUrl), title ?? episodeId);
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        _notify(DownloadNotification(id: episodeId, type: DownloadNotificationType.completed, title: title ?? 'Download complete', progress: 1.0));
        notifyListeners();
        return;
      }

      // Mobile: stream to local file via proxy
      final baseUrl = ApiService.baseUrl;
      final proxyUrl = '$baseUrl/api/proxy?url=${Uri.encodeQueryComponent(audioUrl)}';
      final req = http.Request('GET', Uri.parse(proxyUrl));
      final streamed = await http.Client().send(req).timeout(const Duration(minutes: 5));
      final totalBytes = streamed.contentLength ?? 0;
      int receivedBytes = 0;

      if (_downloadDir != null) {
        final file = File('${_downloadDir!.path}/$episodeId.mp3');
        final sink = file.openWrite();
        await for (final chunk in streamed.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          task.progress = totalBytes > 0 ? receivedBytes / totalBytes : 0.5;
          notifyListeners();
        }
        await sink.close();
        _localFiles[episodeId] = file.path;
      }

      task.status = DownloadStatus.completed;
      task.progress = 1.0;
      _notify(DownloadNotification(id: episodeId, type: DownloadNotificationType.completed, title: title ?? 'Download complete', progress: 1.0));
      notifyListeners();
    } catch (e) {
      task.status = DownloadStatus.failed;
      task.error = e.toString();
      _notify(DownloadNotification(id: episodeId, type: DownloadNotificationType.failed, title: title ?? 'Download failed', error: e.toString(), progress: 0.0));
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
  String? title;

  DownloadTask({
    required this.id,
    required this.source,
    required this.status,
    required this.progress,
    this.error,
    this.title,
  });
}

enum DownloadStatus { idle, downloading, completed, failed }

enum DownloadNotificationType { started, progress, completed, failed }

class DownloadNotification {
  final String id;
  final DownloadNotificationType type;
  final String title;
  final double progress;
  final String? error;

  DownloadNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.progress,
    this.error,
  });

  String get message {
    switch (type) {
      case DownloadNotificationType.started:
        return 'Started downloading...';
      case DownloadNotificationType.progress:
        return 'Downloading ${(progress * 100).toStringAsFixed(0)}%';
      case DownloadNotificationType.completed:
        return 'Downloaded successfully';
      case DownloadNotificationType.failed:
        return 'Download failed: $error';
    }
  }
}