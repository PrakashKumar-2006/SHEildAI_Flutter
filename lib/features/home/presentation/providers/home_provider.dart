import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class HomeProvider extends ChangeNotifier {
  bool _isSOSActive = false;
  int _currentIndex = 0;
  
  // Safety data
  String _currentRiskLevel = 'SAFE';
  int _safetyScore = 85;
  String _currentLocation = 'Scanning location...';
  double? _currentLatitude;
  double? _currentLongitude;

  bool get isSOSActive => _isSOSActive;
  int get currentIndex => _currentIndex;
  String get currentRiskLevel => _currentRiskLevel;
  int get safetyScore => _safetyScore;
  String get currentLocation => _currentLocation;
  double? get currentLatitude => _currentLatitude;
  double? get currentLongitude => _currentLongitude;

  void toggleSOS() {
    _isSOSActive = !_isSOSActive;
    notifyListeners();
  }



  void setIndex(int index) {
    _currentIndex = index;
    notifyListeners();
  }

  void updateLocation(Position position) {
    _currentLatitude = position.latitude;
    _currentLongitude = position.longitude;
    notifyListeners();
  }

  void updateRiskLevel(String riskLevel, int score) {
    _currentRiskLevel = riskLevel;
    _safetyScore = score;
    notifyListeners();
  }

  void updateLocationName(String locationName) {
    _currentLocation = locationName;
    notifyListeners();
  }
}
