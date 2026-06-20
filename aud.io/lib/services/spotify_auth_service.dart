import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aud_io/services/api_service.dart';

class SpotifyTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? artwork;
  final int duration;
  final String? previewUrl;

  SpotifyTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.artwork,
    this.duration = 0,
    this.previewUrl,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    return SpotifyTrack(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      album: json['album'] ?? '',
      artwork: json['artwork'],
      duration: json['duration'] ?? 0,
      previewUrl: json['previewUrl'],
    );
  }
}

class SpotifyPlaylist {
  final String id;
  final String name;
  final String description;
  final String? image;
  final int trackCount;
  final String owner;

  SpotifyPlaylist({
    required this.id,
    required this.name,
    this.description = '',
    this.image,
    this.trackCount = 0,
    this.owner = '',
  });

  factory SpotifyPlaylist.fromJson(Map<String, dynamic> json) {
    return SpotifyPlaylist(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      image: json['image'],
      trackCount: json['trackCount'] ?? 0,
      owner: json['owner'] ?? '',
    );
  }
}

class SpotifyAuthService extends ChangeNotifier {
  static const _clientId = 'c2a22ea075c24aefb1f0d35506c3cecd';
  static const _redirectUri = 'https://aud-io-web.pages.dev/callback';
  static const _scopes = 'playlist-read-private playlist-read-collaborative user-read-private';

  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;
  bool _isLoading = false;

  String? get accessToken => _accessToken;
  bool get isLoggedIn => _accessToken != null;
  bool get isLoading => _isLoading;

  String get authUrl =>
      'https://accounts.spotify.com/authorize'
      '?client_id=$_clientId'
      '&response_type=code'
      '&redirect_uri=${Uri.encodeComponent(_redirectUri)}'
      '&scope=${Uri.encodeComponent(_scopes)}'
      '&show_dialog=true';

  static SpotifyAuthService? _instance;
  static SpotifyAuthService get instance => _instance ??= SpotifyAuthService._();
  SpotifyAuthService._();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('spotify_access_token');
    _refreshToken = prefs.getString('spotify_refresh_token');
    final expiryStr = prefs.getString('spotify_token_expiry');
    if (expiryStr != null) {
      _tokenExpiry = DateTime.tryParse(expiryStr);
    }
    if (_isTokenExpired && _refreshToken != null) {
      await refreshAccessToken();
    }
    notifyListeners();
  }

  bool get _isTokenExpired {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!);
  }

  Future<void> exchangeCode(String code) async {
    _isLoading = true;
    notifyListeners();

    try {
      final resp = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/spotify/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in'] ?? 3600));
        await _saveTokens();
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshAccessToken() async {
    if (_refreshToken == null) return;
    try {
      final resp = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/spotify/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        _accessToken = data['access_token'];
        if (data['refresh_token'] != null) _refreshToken = data['refresh_token'];
        _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in'] ?? 3600));
        await _saveTokens();
      }
    } catch (_) {}
  }

  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) prefs.setString('spotify_access_token', _accessToken!);
    if (_refreshToken != null) prefs.setString('spotify_refresh_token', _refreshToken!);
    if (_tokenExpiry != null) prefs.setString('spotify_token_expiry', _tokenExpiry!.toIso8601String());
  }

  Future<List<SpotifyPlaylist>> getPlaylists() async {
    if (_accessToken == null) return [];
    if (_isTokenExpired) await refreshAccessToken();
    if (_accessToken == null) return [];

    try {
      final resp = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/spotify/playlists?limit=50'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return (data['playlists'] as List).map((p) => SpotifyPlaylist.fromJson(p)).toList();
      } else if (resp.statusCode == 401) {
        await refreshAccessToken();
        return getPlaylists();
      }
    } catch (_) {}
    return [];
  }

  Future<List<SpotifyTrack>> getPlaylistTracks(String playlistId) async {
    if (_accessToken == null) return [];
    if (_isTokenExpired) await refreshAccessToken();
    if (_accessToken == null) return [];

    try {
      final resp = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/spotify/playlists/$playlistId/tracks?limit=100'),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return (data['tracks'] as List).map((t) => SpotifyTrack.fromJson(t)).toList();
      } else if (resp.statusCode == 401) {
        await refreshAccessToken();
        return getPlaylistTracks(playlistId);
      }
    } catch (_) {}
    return [];
  }

  void logout() {
    _accessToken = null;
    _refreshToken = null;
    _tokenExpiry = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('spotify_access_token');
      prefs.remove('spotify_refresh_token');
      prefs.remove('spotify_token_expiry');
    });
    notifyListeners();
  }

  void dispose() {
    super.dispose();
  }
}
