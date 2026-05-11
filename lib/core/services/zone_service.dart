import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
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
  String? _lastTriggeredZoneId;
  bool _isInsideAlertShown = false;
  ZoneModel? _triggeredZone;
  bool _isAlertPopupShowing = false;
  
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
  ZoneModel? get triggeredZone => _triggeredZone;
  bool get isAlertPopupShowing => _isAlertPopupShowing;

  void initialize() {
    _loadZones();
    _startLocationMonitoring();
  }

  Future<void> _loadZones() async {
    try {
      // 1. Load static zones from risk_data.json (Bhopal Dataset)
      final String riskDataString =
          await rootBundle.loadString('assets/risk_data.json');
      final Map<String, dynamic> riskData = jsonDecode(riskDataString);
      final List<dynamic> staticZones = riskData['zones'];
      final Map<String, dynamic> multipliers = riskData['hour_multipliers'];

      final currentHour = DateTime.now().hour;
      // Multiplier is additive: a safe zone (16) + night multiplier (16) = 32 (moderate)
      // This is correct and expected ML behaviour. 
      final double multiplier =
          (multipliers[currentHour.toString()] ?? 0.0).toDouble();

      debugPrint('[ZoneService] Hour: $currentHour, Multiplier: $multiplier');

      final List<ZoneModel> loadedZones = staticZones.map((z) {
        final double baseScore = (z['base_score'] ?? 0.0).toDouble();
        // Clamp to 0-100
        final int finalScore = (baseScore + multiplier).clamp(0.0, 100.0).toInt();

        return ZoneModel.fromRiskScore(
          'static_${z['name']}',
          z['name'],
          LatLng(
            (z['lat'] as num).toDouble(),
            (z['lon'] as num).toDouble(),
          ),
          0.5, // 500m radius for better visibility
          finalScore,
        );
      }).toList();

      // 2. Fetch ML hotspots
      final mlHotspots = await ApiService.fetchHotspots();
      if (mlHotspots != null && mlHotspots.isNotEmpty) {
        final List<ZoneModel> hotspots = mlHotspots.map((z) {
          return ZoneModel.fromRiskScore(
            'ml_${z['id'] ?? z['name']}',
            z['name'] ?? 'Hotspot',
            LatLng(
              (z['lat'] as num).toDouble(),
              (z['lon'] as num).toDouble(),
            ),
            (z['radius'] ?? 0.8).toDouble(),
            (z['risk_score'] ?? 56).toInt(),
          );
        }).toList();

        _zones = [...loadedZones, ...hotspots];
      } else {
        _zones = loadedZones;
      }

      _isDataAvailable = _zones.isNotEmpty;
      debugPrint('[ZoneService] Loaded ${_zones.length} zones.');

      // Log zone type distribution
      final safe = _zones.where((z) => z.zoneType == ZoneType.safe).length;
      final moderate = _zones.where((z) => z.zoneType == ZoneType.moderate).length;
      final high = _zones.where((z) => z.zoneType == ZoneType.high).length;
      final critical = _zones.where((z) => z.zoneType == ZoneType.critical).length;
      debugPrint('[ZoneService] Zone breakdown: Safe=$safe Moderate=$moderate High=$high Critical=$critical');

      notifyListeners();
    } catch (e) {
      debugPrint('[ZoneService] Error loading zones: $e');
      _zones = [];
      _isDataAvailable = false;
      notifyListeners();
    }
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
    
    // Set availability based on nearest zone distance (10km threshold)
    _isDataAvailable = _zones.isNotEmpty && nearestDistance <= 10.0;
    _nearestZone = nearestZone;

    ZoneModel? insideZone;
    int highestRisk = -1;
    for (final zone in _zones) {
      final distance = _calculateDistance(userLocation, zone.center);
      if (distance <= zone.radius) {
        if (zone.riskScore > highestRisk) {
          highestRisk = zone.riskScore;
          insideZone = zone;
        }
      }
    }
    
    if (insideZone != null) { 
      _currentZone = insideZone; 
      // If we are inside a risky zone and haven't shown the alert yet (startup case), show it.
      if (insideZone.requiresAlert && !_isInsideAlertShown) {
        _isInsideAlertShown = true;
        _triggerZoneAlert(insideZone);
      }
    } else { 
      _currentZone = ZoneModel(
        id: 'outside', 
        name: 'Safe Area', 
        center: userLocation, 
        radius: 0, 
        riskScore: 0, 
        zoneType: ZoneType.safe
      ); 
      // Reset inside alert when we leave all risky zones
      _isInsideAlertShown = false;
    }

    _checkZoneEntryAlert(userLocation, nearestZone);
    notifyListeners();
  }

  void _checkZoneEntryAlert(LatLng userLocation, ZoneModel? nearestZone) {
    if (nearestZone == null || !nearestZone.requiresAlert) return;
    final distanceToCenter = _calculateDistance(userLocation, nearestZone.center);
    
    // Proximity logic: Trigger if within 50m of the zone boundary
    // distanceToCenter - nearestZone.radius is the distance to the boundary
    final distanceToBoundary = distanceToCenter - nearestZone.radius;
    
    if (distanceToBoundary <= 0.05 && distanceToBoundary > 0) {
      if (_lastTriggeredZoneId != nearestZone.id) {
        _triggerZoneAlert(nearestZone);
        _lastTriggeredZoneId = nearestZone.id;
        
        // Cooldown: After 5 minutes, we can alert for the same zone again if we leave and return
        _alertCooldownTimer?.cancel();
        _alertCooldownTimer = Timer(const Duration(minutes: 5), () { 
          _lastTriggeredZoneId = null; 
        });
      }
    }
  }

  void _triggerZoneAlert(ZoneModel zone) {
    _triggeredZone = zone;
    _alertTriggered = true;
    _notificationService.showZoneEntryAlert(
      zoneName: zone.name,
      message: zone.alertMessage,
    );
    _startSiren(zone.zoneType);
    notifyListeners();
  }

  void resetAlert() {
    _alertTriggered = false;
    _triggeredZone = null;
    _isAlertPopupShowing = false;
    notifyListeners();
  }

  void setAlertPopupShowing(bool showing) {
    _isAlertPopupShowing = showing;
    notifyListeners();
  }

  Future<void> _startSiren(ZoneType zoneType) async {
    int durationSeconds = 0;
    if (zoneType == ZoneType.moderate) {
      durationSeconds = 4;
    } else if (zoneType == ZoneType.high) {
      durationSeconds = 6;
    } else if (zoneType == ZoneType.critical) {
      durationSeconds = 8;
    }

    if (durationSeconds > 0) {
      _isSirenPlaying = true;
      try {
        await _audioPlayer.setVolume(1.0);
        await _audioPlayer.play(AssetSource('sounds/zone_alert.mp3'));
        
        _sirenTimer?.cancel();
        _sirenTimer = Timer(Duration(seconds: durationSeconds), () {
          stopSiren();
        });
      } catch (e) {
        debugPrint('[ZoneService] Audio Error: $e');
      }
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
    // Return distance in km using precise meters calculation
    final double meters = distance(point1, point2);
    return meters / 1000.0;
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
