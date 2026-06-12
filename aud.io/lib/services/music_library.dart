import 'package:flutter/foundation.dart';
import 'package:aud_io/core/models/track.dart';
import 'package:aud_io/core/theme/witty_strings.dart';
import 'package:aud_io/services/api_service.dart';

class MusicLibrary extends ChangeNotifier {
  List<Track> _queue = [];
  bool _isLoaded = false;
  double _loadProgress = 0.0;
  String _loadStatus = '';

  List<Track> get queue => _queue;
  bool get isLoaded => _isLoaded;
  double get loadProgress => _loadProgress;
  String get loadStatus => _loadStatus;

  Future<void> init() async {
    _loadProgress = 0.0;
    _loadStatus = WittyStrings.randomFrom(WittyStrings.loadingStatuses);
    notifyListeners();

    // Simulate initialization steps with progress
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      _loadProgress = (i + 1) / 5;
      _loadStatus = WittyStrings.randomFrom(WittyStrings.loadingStatuses);
      notifyListeners();
    }

    _isLoaded = true;
    _loadProgress = 1.0;
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
