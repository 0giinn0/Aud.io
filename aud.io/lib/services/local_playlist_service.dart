import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aud_io/core/models/track.dart';

class Playlist {
  final String id;
  String name;
  String description;
  final List<Track> tracks;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    this.description = '',
    List<Track>? tracks,
    DateTime? createdAt,
  })  : tracks = tracks ?? [],
        createdAt = createdAt ?? DateTime.now();

  int get trackCount => tracks.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'],
        name: json['name'],
        description: json['description'] ?? '',
        tracks: (json['tracks'] as List?)?.map((t) => Track.fromJson(t)).toList() ?? [],
        createdAt: DateTime.parse(json['createdAt']),
      );
}

class LocalPlaylistService extends ChangeNotifier {
  static const _key = 'aud_io_playlists';
  static const _favKey = 'aud_io_favorites';
  static const _favTracksKey = 'aud_io_favorite_tracks';
  List<Playlist> _playlists = [];
  Set<String> _favoriteIds = {};
  // Full favourite tracks (newest first) so the Liked Songs view can render
  // and play them — works for music tracks and podcast episodes alike.
  final List<Track> _favorites = [];
  bool _loaded = false;

  List<Playlist> get playlists => List.unmodifiable(_playlists);
  List<Track> get favorites => List.unmodifiable(_favorites);
  int get favoriteCount => _favorites.length;
  bool get loaded => _loaded;

  bool isFavorite(String trackId) => _favoriteIds.contains(trackId);

  void toggleFavorite(Track track) {
    if (_favoriteIds.contains(track.id)) {
      _favoriteIds.remove(track.id);
      _favorites.removeWhere((t) => t.id == track.id);
    } else {
      _favoriteIds.add(track.id);
      _favorites.insert(0, track);
    }
    _saveFavorites();
    notifyListeners();
  }

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _playlists = list.map((e) => Playlist.fromJson(e)).toList();
      } catch (_) {
        _playlists = [];
      }
    }

    final favTracksRaw = prefs.getString(_favTracksKey);
    if (favTracksRaw != null) {
      try {
        final list = jsonDecode(favTracksRaw) as List;
        _favorites
          ..clear()
          ..addAll(list.map((e) => Track.fromJson(e)));
        _favoriteIds = _favorites.map((t) => t.id).toSet();
      } catch (_) {}
    } else {
      // Legacy: only IDs were stored — keep them so isFavorite still works.
      final favRaw = prefs.getStringList(_favKey);
      if (favRaw != null) _favoriteIds = favRaw.toSet();
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_playlists.map((p) => p.toJson()).toList()));
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favKey, _favoriteIds.toList());
    await prefs.setString(_favTracksKey, jsonEncode(_favorites.map((t) => t.toJson()).toList()));
  }

  Playlist createPlaylist(String name, {String description = ''}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final playlist = Playlist(id: id, name: name, description: description);
    _playlists.insert(0, playlist);
    _save();
    notifyListeners();
    return playlist;
  }

  void deletePlaylist(String playlistId) {
    _playlists.removeWhere((p) => p.id == playlistId);
    _save();
    notifyListeners();
  }

  void renamePlaylist(String playlistId, String newName) {
    final p = _playlists.firstWhere((p) => p.id == playlistId);
    p.name = newName;
    _save();
    notifyListeners();
  }

  void addTrackToPlaylist(String playlistId, Track track) {
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    if (!playlist.tracks.any((t) => t.id == track.id)) {
      playlist.tracks.add(track);
      _save();
      notifyListeners();
    }
  }

  void removeTrackFromPlaylist(String playlistId, String trackId) {
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    playlist.tracks.removeWhere((t) => t.id == trackId);
    _save();
    notifyListeners();
  }

  List<Track> getFavorites(List<Track> allTracks) {
    return allTracks.where((t) => _favoriteIds.contains(t.id)).toList();
  }
}
