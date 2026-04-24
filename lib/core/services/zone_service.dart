import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/zone_model.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'api_service.dart';

class ZoneService extends ChangeNotifier {
  final LocationService _locationService;
  final NotificationService _notificationService;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<ZoneModel> _zones = [];
  ZoneModel? _currentZone;
  ZoneModel? _nearestZone;
  bool _isDataAvailable = true;
  bool _alertTriggered = false;
  bool _isSirenPlaying = false;
  
  StreamSubscription? _locationSubscription;
  Timer? _alertCooldownTimer;
  Timer? _sirenTimer;

  ZoneService(this._locationService, this._notificationService);

  List<ZoneModel> get zones => _zones;
  ZoneModel? get currentZone => _currentZone;
  ZoneModel? get nearestZone => _nearestZone;
  bool get isDataAvailable => _isDataAvailable;
  bool get alertTriggered => _alertTriggered;
  bool get isSirenPlaying => _isSirenPlaying;

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
        _zones = await _generateMockZones();
        notifyListeners();
      }
    } catch (e) {
      _zones = await _generateMockZones();
      notifyListeners();
    }
  }

  Future<List<ZoneModel>> _generateMockZones() async {
    final position = await _locationService.getCurrentPosition();
    final baseLat = position.latitude;
    final baseLng = position.longitude;
    return [
      ZoneModel.fromRiskScore('zone_1', 'Local Safety Area', LatLng(baseLat, baseLng), 1.0, 45),
      ZoneModel.fromRiskScore('zone_2', 'North Sector', LatLng(baseLat + 0.01, baseLng), 1.0, 70),
      ZoneModel.fromRiskScore('zone_3', 'South Sector', LatLng(baseLat - 0.01, baseLng), 1.0, 85),
      ZoneModel.fromRiskScore('zone_4', 'East Sector', LatLng(baseLat, baseLng + 0.01), 1.0, 25),
      ZoneModel.fromRiskScore('zone_5', 'West Sector', LatLng(baseLat, baseLng - 0.01), 1.0, 60),
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
    ZoneModel? nearestZone;
    double nearestDistance = double.infinity;
    for (final zone in _zones) {
      final distance = _calculateDistance(userLocation, zone.center);
      if (distance < nearestDistance) { nearestDistance = distance; nearestZone = zone; }
    }
    if (nearestDistance > 10.0) {
      _isDataAvailable = false; _currentZone = null; _nearestZone = null;
      notifyListeners(); return;
    }
    _isDataAvailable = true;
    _nearestZone = nearestZone;

    ZoneModel? insideZone;
    for (final zone in _zones) {
      final distance = _calculateDistance(userLocation, zone.center);
      if (distance <= zone.radius) { insideZone = zone; break; }
    }
    if (insideZone != null) { _currentZone = insideZone; } 
    else { _currentZone = ZoneModel(id: 'outside', name: 'Outside Zone', center: userLocation, radius: 0, riskScore: 0, zoneType: ZoneType.none); }

    _checkZoneEntryAlert(userLocation, nearestZone);
    notifyListeners();
  }

  void _checkZoneEntryAlert(LatLng userLocation, ZoneModel? nearestZone) {
    if (nearestZone == null || !nearestZone.requiresAlert) return;
    final distanceToZone = _calculateDistance(userLocation, nearestZone.center);
    final alertDistance = nearestZone.radius + 0.05; 
    if (distanceToZone <= alertDistance && distanceToZone > nearestZone.radius) {
      if (_alertCooldownTimer == null || !_alertCooldownTimer!.isActive) {
        _triggerZoneAlert(nearestZone);
        _alertCooldownTimer = Timer(const Duration(minutes: 2), () { _alertTriggered = false; });
      }
    }
  }

  void _triggerZoneAlert(ZoneModel zone) {
    _alertTriggered = true;
    _notificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Zone Alert',
      body: zone.alertMessage,
      payload: 'zone_alert_${zone.id}',
    );
    _startSiren(zone.zoneType);
    notifyListeners();
  }

  void _startSiren(ZoneType zoneType) {
    int durationSeconds = 0;
    if (zoneType == ZoneType.moderate) durationSeconds = 4;
    else if (zoneType == ZoneType.high) durationSeconds = 6;
    else if (zoneType == ZoneType.critical) durationSeconds = 8;

    if (durationSeconds > 0) {
      _isSirenPlaying = true;
      _audioPlayer.play(UrlSource('https://actions.google.com/sounds/v1/emergency/ambulance_siren.ogg'));
      
      _sirenTimer?.cancel();
      _sirenTimer = Timer(Duration(seconds: durationSeconds), () {
        stopSiren();
      });
      notifyListeners();
    }
  }

  void stopSiren() {
    _isSirenPlaying = false;
    _audioPlayer.stop();
    _sirenTimer?.cancel();
    notifyListeners();
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _alertCooldownTimer?.cancel();
    _sirenTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
