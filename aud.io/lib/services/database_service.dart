import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aud_io/core/models/track.dart' as aud;

class DatabaseService extends ChangeNotifier {
  final SupabaseClient _client;

  DatabaseService(this._client);

  // ── Profiles ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final resp = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    return resp;
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await _client.from('profiles').update(data).eq('id', userId);
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final resp = await _client
        .from('profiles')
        .select()
        .or('username.ilike.%$query%,display_name.ilike.%$query%')
        .limit(20);
    return List<Map<String, dynamic>>.from(resp);
  }

  // ── Playlists ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPlaylists(String userId) async {
    final resp = await _client
        .from('playlists')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(resp);
  }

  Future<List<Map<String, dynamic>>> getPublicPlaylists({int limit = 20}) async {
    final resp = await _client
        .from('playlists')
        .select('*, profiles!inner(username, display_name, avatar_url)')
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(resp);
  }

  Future<Map<String, dynamic>> createPlaylist(String userId, String name, {String? description}) async {
    final resp = await _client.from('playlists').insert({
      'user_id': userId,
      'name': name,
      'description': description ?? '',
    }).select().single();
    notifyListeners();
    return resp;
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _client.from('playlists').delete().eq('id', playlistId);
    notifyListeners();
  }

  Future<void> updatePlaylist(String playlistId, Map<String, dynamic> data) async {
    await _client.from('playlists').update(data).eq('id', playlistId);
    notifyListeners();
  }

  // ── Playlist Tracks ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPlaylistTracks(String playlistId) async {
    final resp = await _client
        .from('playlist_tracks')
        .select()
        .eq('playlist_id', playlistId)
        .order('position', ascending: true);
    return List<Map<String, dynamic>>.from(resp);
  }

  Future<void> addTrackToPlaylist(String playlistId, aud.Track track, int position) async {
    await _client.from('playlist_tracks').insert({
      'playlist_id': playlistId,
      'track_id': track.id,
      'track_data': {
        'id': track.id,
        'title': track.title,
        'artist': track.artist,
        'album': track.album,
        'thumbnail_url': track.thumbnailUrl,
        'audio_url': track.audioUrl,
        'duration': track.duration,
        'source': track.source.name,
      },
      'position': position,
    });
    await _client.rpc('increment_playlist_track_count', params: {'pid': playlistId});
    notifyListeners();
  }

  Future<void> removeTrackFromPlaylist(String playlistId, int position) async {
    await _client.from('playlist_tracks').delete().eq('playlist_id', playlistId).eq('position', position);
    await _client.rpc('decrement_playlist_track_count', params: {'pid': playlistId});
    notifyListeners();
  }

  // ── Favorites ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFavorites(String userId) async {
    final resp = await _client
        .from('favorites')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(resp);
  }

  Future<bool> isFavorite(String userId, String trackId) async {
    final resp = await _client
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('track_id', trackId)
        .maybeSingle();
    return resp != null;
  }

  Future<void> toggleFavorite(String userId, aud.Track track) async {
    final existing = await _client
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('track_id', track.id)
        .maybeSingle();
    if (existing != null) {
      await _client.from('favorites').delete().eq('id', existing['id']);
    } else {
      await _client.from('favorites').insert({
        'user_id': userId,
        'track_id': track.id,
        'track_data': {
          'id': track.id,
          'title': track.title,
          'artist': track.artist,
          'album': track.album,
          'thumbnail_url': track.thumbnailUrl,
          'duration': track.duration,
          'source': track.source.name,
        },
      });
    }
    notifyListeners();
  }

  // ── History ───────────────────────────────────────────────────────

  Future<void> recordListen(String userId, aud.Track track) async {
    await _client.from('listening_history').insert({
      'user_id': userId,
      'track_id': track.id,
      'track_data': {
        'id': track.id,
        'title': track.title,
        'artist': track.artist,
        'thumbnail_url': track.thumbnailUrl,
        'duration': track.duration,
        'source': track.source.name,
      },
    });
  }

  Future<List<Map<String, dynamic>>> getHistory(String userId, {int limit = 50}) async {
    final resp = await _client
        .from('listening_history')
        .select()
        .eq('user_id', userId)
        .order('listened_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(resp);
  }

  // ── Follows ───────────────────────────────────────────────────────

  Future<bool> isFollowing(String followerId, String followingId) async {
    final resp = await _client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();
    return resp != null;
  }

  Future<void> toggleFollow(String followerId, String followingId) async {
    final existing = await _client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();
    if (existing != null) {
      await _client.from('follows').delete().eq('follower_id', followerId).eq('following_id', followingId);
    } else {
      await _client.from('follows').insert({'follower_id': followerId, 'following_id': followingId});
    }
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    final resp = await _client
        .from('follows')
        .select('follower_id, profiles!follows_follower_id_fkey(username, display_name, avatar_url)')
        .eq('following_id', userId);
    return List<Map<String, dynamic>>.from(resp);
  }

  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    final resp = await _client
        .from('follows')
        .select('following_id, profiles!follows_following_id_fkey(username, display_name, avatar_url)')
        .eq('follower_id', userId);
    return List<Map<String, dynamic>>.from(resp);
  }

  // ── Comments ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getComments(String playlistId) async {
    final resp = await _client
        .from('comments')
        .select('*, profiles!inner(username, display_name, avatar_url)')
        .eq('playlist_id', playlistId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(resp);
  }

  Future<void> addComment(String playlistId, String userId, String content) async {
    await _client.from('comments').insert({
      'playlist_id': playlistId,
      'user_id': userId,
      'content': content,
    });
    notifyListeners();
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('comments').delete().eq('id', commentId);
    notifyListeners();
  }

  // ── Feed (public activity) ────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFeed({int limit = 20}) async {
    final resp = await _client
        .from('playlists')
        .select('*, profiles!inner(username, display_name, avatar_url)')
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(resp);
  }
}
