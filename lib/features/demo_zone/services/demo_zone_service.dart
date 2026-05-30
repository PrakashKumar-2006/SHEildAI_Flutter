import 'package:geolocator/geolocator.dart';
import '../utils/demo_zone_config.dart';

class DemoZoneService {
  bool _isTriggered = false;

  bool get isTriggered => _isTriggered;

  /// Checks if the user has entered the warning zone
  bool shouldTriggerAlert(double currentLat, double currentLng) {
    final distance = Geolocator.distanceBetween(
      currentLat,
      currentLng,
      DemoZoneConfig.demoZoneLat,
      DemoZoneConfig.demoZoneLng,
    );

    if (!_isTriggered && distance <= DemoZoneConfig.triggerDistance) {
      _isTriggered = true;
      return true;
    }

    // Reset logic: only reset if user moves sufficiently far away
    if (_isTriggered && distance > DemoZoneConfig.resetDistance) {
      _isTriggered = false;
    }

    return false;
  }

  double calculateDistance(double currentLat, double currentLng) {
    return Geolocator.distanceBetween(
      currentLat,
      currentLng,
      DemoZoneConfig.demoZoneLat,
      DemoZoneConfig.demoZoneLng,
    );
  }
}
