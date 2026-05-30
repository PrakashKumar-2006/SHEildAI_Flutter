import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/demo_zone_service.dart';
import '../../services/guardian_zone_toggle_service.dart';
import '../../services/guardian_zone_alert_service.dart';
import '../../services/demo_zone_circle_manager.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../../providers/providers.dart';
import '../../../../core/services/storage_service.dart';

class DemoZoneProvider extends ChangeNotifier {
  final DemoZoneService _zoneService = DemoZoneService();
  final GuardianZoneToggleService _toggleService = GuardianZoneToggleService();
  final GuardianZoneAlertService _alertService = GuardianZoneAlertService();
  final DemoZoneCircleManager _circleManager = DemoZoneCircleManager();

  bool _isGuardianAlertEnabled = true;
  Circle? _demoCircle;
  bool _alertTriggered = false;
  bool _isAlertPopupShowing = false;
  
  bool get isGuardianAlertEnabled => _isGuardianAlertEnabled;
  Circle? get demoCircle => _demoCircle;
  bool get alertTriggered => _alertTriggered;
  bool get isAlertPopupShowing => _isAlertPopupShowing;

  DemoZoneProvider() {
    _init();
  }

  Future<void> _init() async {
    _isGuardianAlertEnabled = await _toggleService.isEnabled();
    _demoCircle = _circleManager.buildDemoCircle();
    notifyListeners();
  }

  Future<void> setGuardianAlertEnabled(bool enabled) async {
    _isGuardianAlertEnabled = enabled;
    await _toggleService.setEnabled(enabled);
    notifyListeners();
  }

  void checkZone(LocationProvider locationProvider, SafetyProvider safetyProvider) {
    final position = locationProvider.currentLocation;
    if (position == null) return;

    if (_zoneService.shouldTriggerAlert(position.latitude, position.longitude)) {
      _handleTrigger(position.latitude, position.longitude, safetyProvider);
    }
  }

  void setAlertPopupShowing(bool showing) {
    _isAlertPopupShowing = showing;
    notifyListeners();
  }

  void resetAlert() {
    _alertTriggered = false;
    _isAlertPopupShowing = false;
    notifyListeners();
  }

  void _handleTrigger(double lat, double lng, SafetyProvider safetyProvider) {
    debugPrint('[DemoZone] TRIGGERED at $lat, $lng');
    
    _alertTriggered = true;
    
    // 1. Trigger Siren via SafetyProvider (which calls ZoneService)
    try {
      safetyProvider.startDemoSiren();
      debugPrint('[DemoZone] Siren triggered successfully.');
    } catch (e) {
      debugPrint('[DemoZone] Failed to trigger siren: $e');
    }
    
    notifyListeners();
    
    // 2. Show local alert handled by AppBootstrap via alertTriggered
    
    // 3. If toggle enabled, send guardian alerts
    if (_isGuardianAlertEnabled) {
      // Fetch contacts following SOS logic: StorageService -> SafetyProvider
      List<String> guardianPhones = StorageService().getTrustedContacts();
      
      if (guardianPhones.isEmpty) {
        guardianPhones = safetyProvider.trustedContacts.map((c) => c.phone).toList();
      }
      
      // Aggressive cleaning to ensure SMSService receives pure digits/+
      final cleanedPhones = guardianPhones.map((p) => p.replaceAll(RegExp(r'[^0-9+]'), '')).where((p) => p.isNotEmpty).toList();
      
      debugPrint('[DemoZone] Guardians to notify: ${cleanedPhones.join(", ")}');
      
      if (cleanedPhones.isNotEmpty) {
        _alertService.sendGuardianAlerts(
          guardianPhones: cleanedPhones,
          lat: lat,
          lng: lng,
        );
      } else {
        debugPrint('[DemoZone] WARNING: No guardian contacts found to alert!');
      }
    }
  }
}
