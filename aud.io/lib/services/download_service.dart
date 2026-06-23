import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/api_service.dart';
import 'package:aud_io/services/soundcloud_service.dart';
import 'package:aud_io/services/youtube_explode_service.dart';
import 'package:aud_io/services/cors_proxy.dart';
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

  /// Download a YouTube/SoundCloud track directly from the resolved stream
  /// URL. No server is required — the APK does everything client-side.
  Future<void> downloadTrack(String id, TrackSource source, {String? trackTitle}) async {
    if (_tasks.containsKey(id)) return;
    if (isDownloaded(id)) return;

    final task = DownloadTask(id: id, source: source, status: DownloadStatus.downloading, progress: 0.0, title: trackTitle);
    _tasks[id] = task;
    _notify(DownloadNotification(id: id, type: DownloadNotificationType.started, title: trackTitle ?? 'Download starting', progress: 0.0));
    notifyListeners();

    try {
      // Resolve a direct audio URL for the source.
      String? audioUrl;
      if (source == TrackSource.soundcloud) {
        audioUrl = await SoundCloudService.resolveStreamUrl(id);
      } else if (source == TrackSource.youtube) {
        audioUrl = await YouTubeExplodeService.getAudioUrl(id);
      }

      // Fallback to server proxy if configured.
      if (audioUrl == null && ApiService.hasServer) {
        audioUrl = ApiService.proxyAudioUrl(id, source);
      }

      if (audioUrl == null) {
        throw Exception('Could not resolve a stream URL for $id');
      }

      if (kIsWeb) {
        // Web: open the URL in a new tab to trigger the browser download.
        // Wrap through the CORS proxy so the browser allows the download.
        final webUrl = ApiService.hasServer
            ? audioUrl
            : CorsProxy.wrap(audioUrl);
        triggerDownload(webUrl, trackTitle ?? id);
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        _notify(DownloadNotification(id: id, type: DownloadNotificationType.completed, title: trackTitle ?? 'Download complete', progress: 1.0));
        notifyListeners();
        return;
      }

      // Mobile: stream to a local file.
      final req = http.Request('GET', Uri.parse(audioUrl));
      final streamed = await http.Client().send(req).timeout(const Duration(minutes: 5));
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
        // Web: trigger browser download of the audio URL — through the
        // CORS proxy if no dedicated server is configured.
        final downloadUrl = ApiService.hasServer
            ? ApiService.proxyDirectUrl(audioUrl)
            : CorsProxy.wrap(audioUrl);
        triggerDownload(downloadUrl, title ?? episodeId);
        task.status = DownloadStatus.completed;
        task.progress = 1.0;
        _notify(DownloadNotification(id: episodeId, type: DownloadNotificationType.completed, title: title ?? 'Download complete', progress: 1.0));
        notifyListeners();
        return;
      }

      // Mobile: stream straight from the upstream audio URL — no proxy.
      final req = http.Request('GET', Uri.parse(audioUrl));
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