import 'package:flutter/foundation.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/services/api_service.dart';

class MusicLibrary extends ChangeNotifier {
  List<Track> _queue = [];
  bool _isLoaded = false;

  List<Track> get queue => _queue;
  bool get isLoaded => _isLoaded;

  void init() {
    _isLoaded = true;
    notifyListeners();
  }

  Future<List<Track>> searchAll(String query) async {
    if (query.isEmpty) return [];
    return await ApiService.search(query);
  }

  void setQueue(List<Track> tracks) {
    _queue = List.from(tracks);
    notifyListeners();
  }

  void addToQueue(Track track) {
    _queue.add(track);
    notifyListeners();
  }
}
