import 'package:flutter/foundation.dart';

class HomeProvider extends ChangeNotifier {
  bool _isSOSActive = false;
  bool _isVoiceModeEnabled = false;
  int _currentIndex = 0;

  bool get isSOSActive => _isSOSActive;
  bool get isVoiceModeEnabled => _isVoiceModeEnabled;
  int get currentIndex => _currentIndex;

  void toggleSOS() {
    _isSOSActive = !_isSOSActive;
    notifyListeners();
  }

  void toggleVoiceMode() {
    _isVoiceModeEnabled = !_isVoiceModeEnabled;
    notifyListeners();
  }

  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }
}
