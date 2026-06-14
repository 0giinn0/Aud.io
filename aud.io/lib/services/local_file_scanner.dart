import 'package:flutter/foundation.dart';

class LocalFileScanner extends ChangeNotifier {
  final List<String> _localFiles = [];

  List<String> get localFiles => List.unmodifiable(_localFiles);

  Future<void> scan() async {
    // Stub: local file scanning not yet implemented
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
