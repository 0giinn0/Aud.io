import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/api_service.dart';
import 'package:aud_io/services/youtube_explode_service.dart';

class AppAudioHandler extends BaseAudioHandler with ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  List<Track> _queue = [];
  int? _currentIndex;
  bool _resumeOnInterruptionEnd = false;
  int _retryCount = 0;

  AppAudioHandler() {
    _initSession();
    _initPlayer();
  }

  Future<void> _initSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Pause when headphones are unplugged / Bluetooth disconnects.
      session.becomingNoisyEventStream.listen((_) {
        if (_player.playing) pause();
      });

      // Audio focus: duck for transient interruptions, pause for full ones,
      // resume when the interruption ends (call, navigation prompt, etc).
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.3);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _resumeOnInterruptionEnd = _player.playing;
              if (_player.playing) pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (_resumeOnInterruptionEnd) {
                _resumeOnInterruptionEnd = false;
                play();
              }
              break;
          }
        }
      });
    } catch (e) {
      debugPrint('aud.io: audio session setup failed (ok on web): $e');
    }
  }

  AudioProcessingState _mapProcessing(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle: return AudioProcessingState.idle;
      case ProcessingState.loading: return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready: return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
    }
  }

  void _initPlayer() {
    _player.playerStateStream.listen((state) {
      try {
        playbackState.add(playbackState.value.copyWith(
          playing: state.playing,
          processingState: _mapProcessing(state.processingState),
          controls: [
            MediaControl.skipToPrevious,
            if (state.playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
            MediaControl.stop,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
        ));

        if (state.processingState == ProcessingState.completed && !state.playing) {
          _onTrackComplete();
        }
      } catch (_) {}
    });

    _player.positionStream.listen((pos) {
      try {
        if (mediaItem.value != null) {
          playbackState.add(playbackState.value.copyWith(
            updatePosition: pos,
            bufferedPosition: _player.bufferedPosition,
          ));
        }
      } catch (_) {}
    });

    _player.durationStream.listen((dur) {
      try {
        if (dur != null && mediaItem.value != null) {
          mediaItem.add(mediaItem.value!.copyWith(duration: dur));
        }
      } catch (_) {}
    });
  }

  Uri? _proxiedArtUri(String? thumbnailUrl) {
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) return null;
    // On web, route artwork through the image proxy to fix CORS
    // (most podcast/FMA CDNs don't send Access-Control-Allow-Origin).
    if (kIsWeb) {
      return Uri.parse('${ApiService.baseUrl}/api/proxy-image?url=${Uri.encodeComponent(thumbnailUrl)}');
    }
    return Uri.tryParse(thumbnailUrl);
  }

  MediaItem _toMediaItem(Track track) {
    return MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artistDisplay,
      album: '${track.sourceLabel} · aud.io',
      artUri: _proxiedArtUri(track.thumbnailUrl),
      duration: Duration(seconds: track.duration),
    );
  }

  MediaItem? get _currentMediaItem {
    if (_currentIndex == null || _currentIndex! >= _queue.length) return null;
    return _toMediaItem(_queue[_currentIndex!]);
  }

  void _broadcastQueue() {
    queue.add(_queue.map(_toMediaItem).toList());
  }

  void _onTrackComplete() {
    final mode = playbackState.value.repeatMode;

    if (mode == AudioServiceRepeatMode.one) {
      _loadTrack(_currentIndex!);
      return;
    }

    if (_currentIndex != null && _currentIndex! < _queue.length - 1) {
      _currentIndex = _currentIndex! + 1;
    } else if (mode == AudioServiceRepeatMode.all) {
      _currentIndex = 0;
    } else {
      stop();
      return;
    }

    _loadTrack(_currentIndex!);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    _retryCount = 0;
    await _player.stop();
    _currentIndex = null;
    mediaItem.add(null);
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      processingState: AudioProcessingState.idle,
      updatePosition: Duration.zero,
    ));
    notifyListeners();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    final pos = _player.position;
    if (pos.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    _currentIndex = _currentIndex == null || _currentIndex! <= 0
        ? _queue.length - 1
        : _currentIndex! - 1;
    await _loadTrack(_currentIndex!);
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    if (_currentIndex == null || _currentIndex! >= _queue.length - 1) {
      if (playbackState.value.repeatMode == AudioServiceRepeatMode.all) {
        _currentIndex = 0;
      } else {
        await stop();
        return;
      }
    } else {
      _currentIndex = _currentIndex! + 1;
    }
    await _loadTrack(_currentIndex!);
  }

  Future<Uri?> _resolvePlaybackUri(Track track) async {
    switch (track.source) {
      case TrackSource.local:
        final path = track.audioUrl;
        if (path == null) return null;
        if (path.startsWith('http') || path.startsWith('file://') || path.startsWith('content://')) {
          return Uri.parse(path);
        }
        return Uri.file(path);
      case TrackSource.youtube:
        // Mobile: extract direct googlevideo URL via InnerTube (no server).
        // Web: route through the server proxy (YouTube API has no CORS).
        if (kIsWeb) {
          return Uri.parse(ApiService.proxyAudioUrl(track.id, track.source));
        }
        // Use prefetched URL if available, otherwise resolve fresh.
        final cached = track.audioUrl;
        final directUrl = cached ?? await YouTubeExplodeService.getAudioUrl(track.id);
        if (directUrl != null) {
          if (cached == null) track.audioUrl = directUrl;
          return Uri.parse(directUrl);
        }
        return null;
      case TrackSource.podcast:
        final purl = track.audioUrl;
        if (purl == null) return null;
        // Podcast hosts rarely send CORS headers, so on web go through the
        // generic proxy; native can hit the URL directly.
        return Uri.parse(kIsWeb ? ApiService.proxyDirectUrl(purl) : purl);
      default:
        // On web, route through the proxy too: it adds the CORS headers the
        // browser requires, follows upstream redirects server-side, and serves
        // progressive bytes with Range support. Native plays the direct
        // upstream URL (no CORS limits) to save a hop.
        if (kIsWeb) {
          return Uri.parse(ApiService.proxyAudioUrl(track.id, track.source));
        }
        final url = track.audioUrl ??= await ApiService.getStreamUrl(track.id, track.source);
        return url != null ? Uri.parse(url) : null;
    }
  }

  /// Warm up the next track so skips start instantly: for YouTube this
  /// pre-extracts the stream URL into the cache; for SoundCloud/FMA
  /// it stores the resolved URL on the track.
  void _prefetchNext() {
    final idx = _currentIndex;
    if (idx == null || idx + 1 >= _queue.length) return;
    final next = _queue[idx + 1];
    if (next.source == TrackSource.local ||
        next.source == TrackSource.fake ||
        next.source == TrackSource.podcast) return;

    // YouTube on mobile: pre-warm the InnerTube cache.
    if (next.source == TrackSource.youtube && !kIsWeb) {
      YouTubeExplodeService.getAudioUrl(next.id).then((url) {
        if (url != null) next.audioUrl = url;
      }).catchError((_) {});
      return;
    }

    // Non-YouTube (or YouTube on web): route through the server proxy.
    if (next.audioUrl != null) return;
    ApiService.getStreamUrl(next.id, next.source).then((url) {
      if (url != null) next.audioUrl = url;
    }).catchError((_) {});
  }

  Future<void> _loadTrack(int index) async {
    if (index < 0 || index >= _queue.length) return;
    final track = _queue[index];
    _currentIndex = index;
    mediaItem.add(_currentMediaItem);
    playbackState.add(playbackState.value.copyWith(queueIndex: index));

    try {
      final uri = await _resolvePlaybackUri(track);
      if (uri == null) {
        debugPrint('aud.io: no stream URL for ${track.id}');
        _retryCount++;
        if (_retryCount >= _queue.length) {
          debugPrint('aud.io: all tracks exhausted, stopping');
          await stop();
          return;
        }
        skipToNext();
        return;
      }

      await _player.setAudioSource(AudioSource.uri(uri));
      _retryCount = 0;
      notifyListeners();
      await _player.play();
      _prefetchNext();
    } catch (e) {
      debugPrint('aud.io: failed to load: $e');
      _retryCount++;
      if (_retryCount >= _queue.length) {
        debugPrint('aud.io: all tracks exhausted, stopping');
        await stop();
        return;
      }
      skipToNext();
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _retryCount = 0;
    await _loadTrack(index);
  }

  void setQueue(List<Track> tracks, {int? startIndex}) {
    _retryCount = 0;
    _queue = List.from(tracks);
    _currentIndex = startIndex ?? 0;
    _broadcastQueue();
    if (_queue.isNotEmpty) {
      notifyListeners();
      _loadTrack(_currentIndex!);
    }
  }

  void addToQueue(Track track) {
    _queue.add(track);
    _broadcastQueue();
  }

  /// Drag-reorder the queue while keeping the currently-playing track current.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    final current = _currentIndex != null ? _queue[_currentIndex!] : null;
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > _queue.length - 1) newIndex = _queue.length - 1;
    final track = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, track);
    if (current != null) _currentIndex = _queue.indexOf(current);
    _broadcastQueue();
    playbackState.add(playbackState.value.copyWith(queueIndex: _currentIndex));
    notifyListeners();
  }

  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      if (_currentIndex != null && index < _currentIndex!) {
        _currentIndex = _currentIndex! - 1;
      }
      _broadcastQueue();
    }
  }

  void clearQueue() {
    _queue.clear();
    _currentIndex = null;
    _broadcastQueue();
    stop();
  }

  Future<void> playDirectUrl(String url, {String? title, String? artist, String? artUri, int? durationMs}) async {
    try {
      final source = AudioSource.uri(Uri.parse(url));
      await _player.setAudioSource(source);
      notifyListeners();

      mediaItem.add(MediaItem(
        id: 'podcast_${DateTime.now().millisecondsSinceEpoch}',
        title: title ?? 'Podcast',
        artist: artist ?? 'Podcast',
        album: 'Podcast · aud.io',
        artUri: _proxiedArtUri(artUri),
        duration: durationMs != null ? Duration(milliseconds: durationMs) : null,
      ));

      playbackState.add(playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.pause,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
      ));

      await _player.play();
    } catch (e) {
      debugPrint('aud.io: failed to play podcast: $e');
    }
  }

  List<Track> get queueList => List.unmodifiable(_queue);
  int? get currentIndex => _currentIndex;
  Track? get currentTrack =>
      _currentIndex != null && _currentIndex! < _queue.length ? _queue[_currentIndex!] : null;

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }

  void toggleShuffle() {
    final current = playbackState.value.shuffleMode;
    setShuffleMode(current == AudioServiceShuffleMode.all
        ? AudioServiceShuffleMode.none
        : AudioServiceShuffleMode.all);
  }

  void cycleRepeatMode() {
    final current = playbackState.value.repeatMode;
    final next = switch (current) {
      AudioServiceRepeatMode.none  => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all   => AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one   => AudioServiceRepeatMode.none,
      AudioServiceRepeatMode.group => AudioServiceRepeatMode.none,
    };
    setRepeatMode(next);
  }

  Stream<PositionData> get positionStream => Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (pos, buf, dur) => PositionData(pos, buf, dur ?? Duration.zero),
      );

  AudioPlayer get player => _player;

  void disposePlayer() {
    _player.dispose();
  }
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}
