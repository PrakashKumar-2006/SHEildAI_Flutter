import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/zone_model.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'api_service.dart';

class ZoneService extends ChangeNotifier {
  final LocationService _locationService;
  final NotificationService _notificationService;
  
  List<ZoneModel> _zones = [];
  ZoneModel? _currentZone;
  ZoneModel? _nearestZone;
  bool _isDataAvailable = true;
  bool _alertTriggered = false;
  StreamSubscription? _locationSubscription;
  Timer? _alertCooldownTimer;
  Timer? _alertSoundTimer;

  ZoneService(this._locationService, this._notificationService);

  List<ZoneModel> get zones => _zones;
  ZoneModel? get currentZone => _currentZone;
  ZoneModel? get nearestZone => _nearestZone;
  bool get isDataAvailable => _isDataAvailable;
  bool get alertTriggered => _alertTriggered;

  void initialize() {
    _loadZones();
    _startLocationMonitoring();
  }

  Future<void> _loadZones() async {
    try {
      final position = await _locationService.getCurrentPosition();
      final userLat = position.latitude;
      final userLng = position.longitude;
      
      final mlZones = await ApiService.getHotspots(userLat, userLng, 10.0);
      
      if (mlZones != null && mlZones.isNotEmpty) {
        updateZonesFromML(mlZones);
      } else {
        _zones = _generateMockZones();
        notifyListeners();
      }
    } catch (e) {
      _zones = _generateMockZones();
      notifyListeners();
    }
  }

  List<ZoneModel> _generateMockZones() {
    // Generate mock zones around the default location (Indore, India)
    final baseLat = 22.7196;
    final baseLng = 75.8577;
    
    return [
      ZoneModel.fromRiskScore(
        'zone_1',
        'Central Zone',
        LatLng(baseLat, baseLng),
        1.0, // 1km radius
        45, // Moderate
      ),
      ZoneModel.fromRiskScore(
        'zone_2',
        'North Zone',
        LatLng(baseLat + 0.02, baseLng),
        1.0,
        70, // High
      ),
      ZoneModel.fromRiskScore(
        'zone_3',
        'South Zone',
        LatLng(baseLat - 0.02, baseLng),
        1.0,
        85, // Critical
      ),
      ZoneModel.fromRiskScore(
        'zone_4',
        'East Zone',
        LatLng(baseLat, baseLng + 0.02),
        1.0,
        25, // Safe
      ),
      ZoneModel.fromRiskScore(
        'zone_5',
        'West Zone',
        LatLng(baseLat, baseLng - 0.02),
        1.0,
        60, // High
      ),
    ];
  }

  void updateZonesFromML(List<dynamic> mlZones) {
    _zones = mlZones.map((zoneData) {
      return ZoneModel.fromRiskScore(
        zoneData['id'] ?? 'unknown',
        zoneData['name'] ?? 'Unknown Zone',
        LatLng(zoneData['lat'] ?? 0.0, zoneData['lon'] ?? 0.0),
        (zoneData['radius'] ?? 1.0).toDouble(),
        (zoneData['risk_score'] ?? 0).toInt(),
      );
    }).toList();
    notifyListeners();
  }

  void _startLocationMonitoring() {
    _locationSubscription = _locationService.positionStream.listen((location) {
      _checkZoneProximity(location.latitude, location.longitude);
    });
  }

  void _checkZoneProximity(double userLat, double userLng) {
    final userLocation = LatLng(userLat, userLng);
    
    // Find the nearest zone within 10km
    ZoneModel? nearestZone;
    double nearestDistance = double.infinity;
    
    for (final zone in _zones) {
      final distance = _calculateDistance(userLocation, zone.center);
      
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestZone = zone;
      }
    }

    // Check if any zone is within 10km
    if (nearestDistance > 10.0) {
      _isDataAvailable = false;
      _currentZone = null;
      _nearestZone = null;
      notifyListeners();
      return;
    }

    _isDataAvailable = true;
    _nearestZone = nearestZone;

    // Check if user is inside any zone
    ZoneModel? insideZone;
    for (final zone in _zones) {
      final distance = _calculateDistance(userLocation, zone.center);
      if (distance <= zone.radius) {
        insideZone = zone;
        break;
      }
    }

    if (insideZone != null) {
      _currentZone = insideZone;
    } else {
      // User is outside any zone - show risk score 0, safe zone
      _currentZone = ZoneModel(
        id: 'outside',
        name: 'Outside Zone',
        center: userLocation,
        radius: 0,
        riskScore: 0,
        zoneType: ZoneType.none,
      );
    }

    // Check for zone entry alert (50m before entering)
    _checkZoneEntryAlert(userLocation, nearestZone);

    // Notify listeners to update UI in real-time
    notifyListeners();
  }

  void _checkZoneEntryAlert(LatLng userLocation, ZoneModel? nearestZone) {
    if (nearestZone == null || !nearestZone.requiresAlert) return;
    
    final distanceToZone = _calculateDistance(userLocation, nearestZone.center);
    final alertDistance = nearestZone.radius + 0.05; // 50m before entering (0.05km)

    // Check if user is approaching the zone (within 50m of zone boundary)
    if (distanceToZone <= alertDistance && distanceToZone > nearestZone.radius) {
      // Check if alert was recently triggered (cooldown to avoid spam)
      if (_alertCooldownTimer == null || !_alertCooldownTimer!.isActive) {
        _triggerZoneAlert(nearestZone);
        // Set cooldown for 2 minutes
        _alertCooldownTimer = Timer(const Duration(minutes: 2), () {
          _alertTriggered = false;
        });
      }
    }
  }

  void _triggerZoneAlert(ZoneModel zone) {
    _alertTriggered = true;
    
    // Show notification
    _notificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Zone Alert',
      body: zone.alertMessage,
      payload: 'zone_alert_${zone.id}',
    );

    // Play alert sound/siren
    _playAlertSound(zone.zoneType);

    notifyListeners();
  }

  void _playAlertSound(ZoneType zoneType) {
    if (zoneType == ZoneType.critical || zoneType == ZoneType.high) {
      _notificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1,
        title: '⚠️ DANGER: HIGH RISK ZONE',
        body: 'You have entered a high risk zone. Stay alert and keep your phone accessible.',
        payload: 'zone_siren',
      );
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  List<ZoneModel> getZonesWithinRadius(LatLng center, double radiusKm) {
    return _zones.where((zone) {
      final distance = _calculateDistance(center, zone.center);
      return distance <= radiusKm;
    }).toList();
  }

  ZoneModel? getZoneAtLocation(LatLng location) {
    for (final zone in _zones) {
      final distance = _calculateDistance(location, zone.center);
      if (distance <= zone.radius) {
        return zone;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _alertCooldownTimer?.cancel();
    _alertSoundTimer?.cancel();
    super.dispose();
  }
}
