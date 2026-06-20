import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/core/models/playlist_model.dart';

class LocalPlaylistService extends ChangeNotifier {
  static const _favBox = 'favorites';
  static const _playlistBox = 'playlists';
  static const _historyBox = 'history';

  final Set<String> _favoriteIds = {};
  final Map<String, Track> _favoriteTracks = {};
  final List<PlaylistModel> _playlists = [];
  final List<Track> _history = [];

  bool _loaded = false;

  List<PlaylistModel> get playlists => List.unmodifiable(_playlists);
  List<Track> get favorites => _favoriteIds.map((id) => _favoriteTracks[id]!).whereType<Track>().toList();
  int get favoriteCount => _favoriteIds.length;
  List<Track> get history => List.unmodifiable(_history);
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final favBox = await Hive.openBox<String>(_favBox);
      final playlistBox = await Hive.openBox<String>(_playlistBox);
      final historyBox = await Hive.openBox<String>(_historyBox);

      for (final entry in favBox.toMap().entries) {
        _favoriteIds.add(entry.key);
        final json = entry.value;
        if (json.isNotEmpty) {
          try {
            _favoriteTracks[entry.key] = Track.fromJson(jsonDecode(json) as Map<String, dynamic>);
          } catch (_) {}
        }
      }

      for (final entry in playlistBox.toMap().entries) {
        try {
          final json = jsonDecode(entry.value) as Map<String, dynamic>;
          final tracks = (json['tracks'] as List<dynamic>? ?? [])
              .map((t) => Track.fromJson(t as Map<String, dynamic>))
              .toList();
          _playlists.add(PlaylistModel(
            id: entry.key.hashCode,
            name: json['name'] as String? ?? '',
            tracks: tracks,
            createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
          ));
        } catch (_) {}
      }

      for (final entry in historyBox.toMap().entries) {
        try {
          _history.add(Track.fromJson(jsonDecode(entry.value) as Map<String, dynamic>));
        } catch (_) {}
      }
    } catch (_) {}

    _loaded = true;
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    try {
      final box = await Hive.openBox<String>(_favBox);
      await box.clear();
      for (final id in _favoriteIds) {
        final track = _favoriteTracks[id];
        if (track != null) {
          await box.put(id, jsonEncode(track.toJson()));
        }
      }
    } catch (_) {}
  }

  Future<void> _savePlaylists() async {
    try {
      final box = await Hive.openBox<String>(_playlistBox);
      await box.clear();
      for (var i = 0; i < _playlists.length; i++) {
        final p = _playlists[i];
        await box.put(
          'playlist_$i',
          jsonEncode({
            'name': p.name,
            'createdAt': p.createdAt.toIso8601String(),
            'tracks': p.tracks.map((t) => t.toJson()).toList(),
          }),
        );
      }
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final box = await Hive.openBox<String>(_historyBox);
      await box.clear();
      for (var i = 0; i < _history.length; i++) {
        await box.put(i.toString(), jsonEncode(_history[i].toJson()));
      }
    } catch (_) {}
  }

  bool isFavorite(String trackId) => _favoriteIds.contains(trackId);

  Future<void> toggleFavorite(Track track) async {
    if (_favoriteIds.contains(track.id)) {
      _favoriteIds.remove(track.id);
      _favoriteTracks.remove(track.id);
    } else {
      _favoriteIds.add(track.id);
      _favoriteTracks[track.id] = track;
    }
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> addToPlaylist(String name, Track track) async {
    final existing = _playlists.where((p) => p.name == name).firstOrNull;
    if (existing != null) {
      final idx = _playlists.indexOf(existing);
      _playlists[idx] = existing.copyWith(tracks: [...existing.tracks, track]);
    } else {
      _playlists.add(PlaylistModel(name: name, tracks: [track]));
    }
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> createPlaylist(String name) async {
    _playlists.add(PlaylistModel(name: name));
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => '${p.id}' == id);
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final idx = _playlists.indexWhere((p) => '${p.id}' == playlistId);
    if (idx == -1) return;
    final p = _playlists[idx];
    _playlists[idx] = p.copyWith(tracks: p.tracks.where((t) => t.id != trackId).toList());
    await _savePlaylists();
    notifyListeners();
  }

  Future<void> addToHistory(Track track) async {
    _history.removeWhere((t) => t.id == track.id);
    _history.insert(0, track);
    if (_history.length > 200) _history.removeLast();
    await _saveHistory();
  }

  Future<void> clearAll() async {
    _favoriteIds.clear();
    _favoriteTracks.clear();
    _playlists.clear();
    _history.clear();
    try {
      await Hive.deleteBoxFromDisk(_favBox);
      await Hive.deleteBoxFromDisk(_playlistBox);
      await Hive.deleteBoxFromDisk(_historyBox);
    } catch (_) {}
    notifyListeners();
  }

  void dispose() {
    super.dispose();
  }
}
