import 'dart:async';
import 'dart:convert';
import '../core/constants/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/localization.dart';
import '../core/app_theme.dart';
import '../features/sos/presentation/providers/sos_provider.dart';
import '../features/location/presentation/providers/location_provider.dart';
import '../core/providers/ml_provider.dart';
import '../core/services/location_service.dart';
import '../core/services/sos_platform_service.dart';
import '../core/services/zone_service.dart';
import '../features/voice/presentation/providers/voice_provider.dart';
import '../features/shake_sos/providers/shake_sos_provider.dart';
import '../features/sos/domain/models/sos_model.dart';
import '../core/models/zone_model.dart';
import '../core/services/sms_service.dart';
import '../core/services/api_service.dart' as api;
import '../features/community/presentation/providers/community_provider.dart';
import '../core/services/socket_service.dart';
import '../core/services/osrm_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/mongo_service.dart';
import '../features/wearable/services/wearable_alert_manager.dart';

// ─── Theme Provider ────────────────────────────────────────────────────────────
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;
  ThemeProvider() { _loadTheme(); }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getString('@app_theme') == 'dark';
    notifyListeners();
  }
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('@app_theme', _isDarkMode ? 'dark' : 'light');
    notifyListeners();
  }
  Color get background => _isDarkMode ? AppColors.darkBackground : AppColors.lightBackground;
  Color get surface => _isDarkMode ? AppColors.darkSurface : AppColors.lightSurface;
  Color get textPrimary => _isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondary => _isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get accent => _isDarkMode ? AppColors.darkAccent : AppColors.lightAccent;
  Color get danger => _isDarkMode ? AppColors.darkDanger : AppColors.lightDanger;
  Color get border => _isDarkMode ? AppColors.darkBorder : AppColors.lightBorder;
}

// ─── Language Provider ─────────────────────────────────────────────────────────
class LanguageProvider extends ChangeNotifier {
  String _language = 'en';
  String get language => _language;
  LanguageProvider() { _loadLanguage(); }
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('@app_language') ?? 'en';
    notifyListeners();
  }
  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('@app_language', lang);
    notifyListeners();
  }
  String t(String key) => AppStrings.get(key, _language);
}

// ─── Models ──────────────────────────────────────────────────────────────────
class GuardianContact {
  final String name;
  final String phone;
  GuardianContact({required this.name, required this.phone});
  
  Map<String, String> toJson() => {'name': name, 'phone': phone};
  factory GuardianContact.fromJson(Map<String, dynamic> json) => 
    GuardianContact(name: json['name'] ?? '', phone: json['phone'] ?? '');
}

class UserProfile {
  String name; String phone; List<GuardianContact> trustedContacts; bool isComplete; bool isSetupComplete;
  UserProfile({this.name = '', this.phone = '', this.trustedContacts = const [], this.isComplete = false, this.isSetupComplete = false});
  UserProfile copyWith({String? name, String? phone, List<GuardianContact>? trustedContacts, bool? isComplete, bool? isSetupComplete}) {
    return UserProfile(name: name ?? this.name, phone: phone ?? this.phone, trustedContacts: trustedContacts ?? this.trustedContacts, isComplete: isComplete ?? this.isComplete, isSetupComplete: isSetupComplete ?? this.isSetupComplete);
  }
}

class AlertItem {
  final String id; final String type; final String title; final String body; final DateTime timestamp; final String? riskLevel;
  final double? latitude; final double? longitude;
  AlertItem({required this.id, required this.type, required this.title, required this.body, required this.timestamp, this.riskLevel, this.latitude, this.longitude});
}

// ─── Safety Provider (Bridge) ───────────────────────────────────────────────────
class SafetyProvider extends ChangeNotifier {
  bool _isAppReady = false;
  UserProfile _userProfile = UserProfile();
  List<GuardianContact> _trustedContacts = [];
  List<GuardianContact> _inputContacts = [GuardianContact(name: '', phone: '')];
  final List<AlertItem> _alerts = [];
  AlertItem? _pendingSOSAlert;
  String _readableAddress = 'Scanning location...';
  Timer? _durationTimer;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  DateTime? _lastMLUpdate;
  
  final Battery _battery = Battery();
  final Connectivity _connectivity = Connectivity();
  int _currentBatteryLevel = 100;
  bool _hasInternet = true;

  SOSProvider? _sosProvider;
  LocationProvider? _locationProvider;
  MLProvider? _mlProvider;
  ZoneService? _zoneService;
  VoiceProvider? _voiceProvider;
  ShakeSosProvider? _shakeSosProvider;
  CommunityProvider? _communityProvider;

  bool get isAppReady => _isAppReady;
  UserProfile get userProfile => _userProfile;
  List<GuardianContact> get trustedContacts => _trustedContacts;
  List<GuardianContact> get inputContacts => _inputContacts;
  bool get isSOSActive => _sosProvider?.isSOSActive ?? false;

  String get sosState {
    final native = _sosProvider?.nativeState;
    if (native == SOSNativeState.recordingAudio || native == SOSNativeState.recordingVideo) return 'RECORDING';
    if (isSOSActive) return 'SOS_ACTIVE';
    if (native == SOSNativeState.cooldown) return 'RECOVERING';
    return 'IDLE';
  }
  
  String? get sosSessionId => _sosProvider?.activeSOS?.id;
  DateTime? get sosSessionStart => _sosProvider?.activeSOS?.timestamp;
  
  int get activeSessionDuration {
    if (sosSessionStart == null) return 0;
    return DateTime.now().difference(sosSessionStart!).inSeconds;
  }
  
  int get recordingTimeLeft => 120 - (activeSessionDuration % 120);
  
  String get riskLabel {
    if (!(_zoneService?.isDataAvailable ?? false)) return 'N/A (Coming Soon)';
    final score = riskScore;
    if (_zoneService?.currentZone?.id == 'outside' || score <= 25) return 'SAFE ZONE';
    if (score <= 50) return 'MEDIUM';
    if (score <= 75) return 'HIGH';
    return 'CRITICAL';
  }

  int get riskScore {
    if (!(_zoneService?.isDataAvailable ?? false)) return 0;
    final mlScore = (_mlProvider?.riskPrediction?['risk_score'] ?? 0).toInt();
    final zoneScore = (_zoneService?.currentZone?.riskScore ?? 0).toInt();
    return mlScore > zoneScore ? mlScore : zoneScore;
  }

  // Exposed factors for UI breakdown
  int get mlRiskScore => (_mlProvider?.riskPrediction?['risk_score'] ?? 0).toInt();
  int get zoneRiskScore => (_zoneService?.currentZone?.riskScore ?? 0).toInt();
  String get currentZoneName => _zoneService?.currentZone?.name ?? 'Outside Zone';

  String get riskColor {
    if (!(_zoneService?.isDataAvailable ?? false)) return '#94A3B8';
    final score = riskScore;
    if (_zoneService?.currentZone?.id == 'outside' || score <= 25) return '#43A047';
    if (score <= 50) return '#FBC02D';
    if (score <= 75) return '#F57C00';
    return '#D32F2F';
  }
  
  List<String> get riskAlerts => List<String>.from(_mlProvider?.riskPrediction?['alerts'] ?? []);
  Map<String, dynamic>? get bestTravelTime => _mlProvider?.bestTravelTime;
  Map<String, dynamic>? get forecast => _mlProvider?.forecast;
  String get readableAddress => _readableAddress;
  bool get isSafetyModeActive => _voiceProvider?.isEnabled ?? false;
  bool get isShakeTriggerEnabled => _shakeSosProvider?.isEnabled ?? false;
  bool get isSirenPlaying => _zoneService?.isSirenPlaying ?? false;

  List<AlertItem> get alerts {
    final List<AlertItem> all = List.from(_alerts);
    if (_communityProvider != null) {
      for (var r in _communityProvider!.reports) {
        final commId = 'comm_rep_${r.id}';
        if (!all.any((a) => a.id == commId || a.id == r.id)) {
          all.add(AlertItem(
            id: commId,
            type: 'REPORT',
            title: r.incidentType,
            body: r.description,
            timestamp: r.timestamp,
            riskLevel: r.severity > 7 ? 'HIGH' : r.severity > 4 ? 'MEDIUM' : 'LOW',
            latitude: r.latitude,
            longitude: r.longitude,
          ));
        }
      }
    }
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all;
  }

  double? get latitude => _locationProvider?.currentLocation?.latitude;
  double? get longitude => _locationProvider?.currentLocation?.longitude;
  List<ZoneModel> get zones => _zoneService?.zones ?? [];
  AlertItem? get pendingSOSAlert => _pendingSOSAlert;

  SafetyProvider() { 
    _init(); 
    _startTimer();
    _startHardwareMonitoring();
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isSOSActive || isSirenPlaying) notifyListeners();
    });
  }

  void _startHardwareMonitoring() {
    _battery.batteryLevel.then((level) => _currentBatteryLevel = level);
    _battery.onBatteryStateChanged.listen((_) async {
      _currentBatteryLevel = await _battery.batteryLevel;
    });
    _connectivity.onConnectivityChanged.listen((result) {
      _hasInternet = result != ConnectivityResult.none;
    });
  }

  void _onSOSStateChanged() => notifyListeners();

  void update(SOSProvider sos, LocationProvider loc, MLProvider ml, ZoneService zone, VoiceProvider voice, CommunityProvider community, ShakeSosProvider shake) {
    // Re-subscribe only when the SOSProvider instance actually changes.
    if (_sosProvider != sos) {
      _sosProvider?.removeListener(_onSOSStateChanged);
      _sosProvider = sos;
      _sosProvider?.addListener(_onSOSStateChanged);
    }
    _locationProvider = loc;
    _mlProvider = ml;
    _zoneService = zone;
    _voiceProvider = voice;
    _shakeSosProvider = shake;
    _communityProvider = community;
    _syncCommunityReports();
    _syncWithLocation();
  }

  void _syncCommunityReports() {
    if (_communityProvider == null || _communityProvider!.reports.isEmpty) return;

    bool changed = false;
    for (var report in _communityProvider!.reports) {
      final alertId = 'report_${report.id}';
      // Check if this report already exists in our alerts list
      if (!_alerts.any((a) => a.id == alertId)) {
        _alerts.add(AlertItem(
          id: alertId,
          type: 'REPORT',
          title: report.incidentType,
          body: report.description,
          timestamp: report.timestamp,
          riskLevel: report.severity > 7 ? 'HIGH' : report.severity > 4 ? 'MEDIUM' : 'LOW',
          latitude: report.latitude,
          longitude: report.longitude,
        ));
        changed = true;
      }
    }

    if (changed) {
      // Sort alerts by timestamp descending to keep newest at top
      _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      // No need to call notifyListeners here as we are inside the update() 
      // which is called by ProxyProvider, which will notify its listeners anyway.
    }
  }

  void _syncWithLocation() {
    if (_locationProvider?.currentLocation != null) {
      final lat = _locationProvider!.currentLocation!.latitude;
      final lon = _locationProvider!.currentLocation!.longitude;
      LocationService().getAddressFromLatLng(lat, lon).then((addr) {
        if (_readableAddress != addr) {
          _readableAddress = addr;
          notifyListeners();
        }
      });

      final now = DateTime.now();
      if (_lastMLUpdate == null || now.difference(_lastMLUpdate!).inMinutes >= 1) {
        _lastMLUpdate = now;
        Future.wait([
          _mlProvider?.predictRisk(lat: lat, lon: lon, hour: now.hour, month: now.month, battery: _currentBatteryLevel, internet: _hasInternet, isWeekend: (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) ? 1 : 0) ?? Future.value(),
          _mlProvider?.getForecast(lat: lat, lon: lon, currentHour: now.hour, month: now.month, isWeekend: (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) ? 1 : 0) ?? Future.value(),
          _mlProvider?.getBestTravelTime(lat: lat, lon: lon, month: now.month, isWeekend: (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) ? 1 : 0) ?? Future.value(),
          _communityProvider?.loadNearbyReports(latitude: lat, longitude: lon, radiusKm: 20) ?? Future.value(),
        ]);
      }
    }
  }

  Future<void> _init() async {
    await _loadUserProfile();
    if (_userProfile.phone.isNotEmpty) {
      await SocketService().connect(_userProfile.phone);
      _listenToSocket();
      _listenToConnection();
    }
    _isAppReady = true;
    notifyListeners();
  }

  void _listenToConnection() {
    SocketService().connectionStream.listen((connected) {
      if (connected && latitude != null && longitude != null) {
        debugPrint('[SafetyProvider] Socket connected, syncing initial location...');
        SocketService().emitLocationUpdate(latitude!, longitude!);
      }
    });
  }

  void _listenToSocket() {
    _messageSubscription = SocketService().messageStream.listen((data) {
      final event = data['event'];
      debugPrint('[SafetyProvider] Received socket event: $event');
      try {
        final payload = data['data'] ?? data;
        
        if (event == 'sentinel_alert' || event == 'emergency_nearby' || event == 'sos_broadcast') {
          final double victimLat = double.tryParse(payload['latitude']?.toString() ?? payload['lat']?.toString() ?? '0') ?? 0.0;
          final double victimLng = double.tryParse(payload['longitude']?.toString() ?? payload['lng']?.toString() ?? '0') ?? 0.0;
          final String victimName = payload['name']?.toString() ?? data['name']?.toString() ?? 'Someone';
          final String sosId = (payload['sosId'] ?? payload['sos_id'])?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
          
          if (victimLat != 0.0 && latitude != null && longitude != null) {
            final distanceMeters = OSRMService.calculateDistance(latitude!, longitude!, victimLat, victimLng);
            // 5km radius for sentinel alerts
            if (distanceMeters <= 5000.0) {
              _addCommunitySOSAlert(victimName, victimLat, victimLng, sosId, distanceMeters);
            }
          }
        } else if (event == 'new_community_report' || event == 'community_report' || event == 'community_report_broadcast') {
          // Handle real-time community report from another user
          final double reportLat = double.tryParse(payload['latitude']?.toString() ?? payload['lat']?.toString() ?? '0') ?? 0.0;
          final double reportLng = double.tryParse(payload['longitude']?.toString() ?? payload['lng']?.toString() ?? '0') ?? 0.0;
          final String type = payload['incidentType']?.toString() ?? payload['type']?.toString() ?? 'Safety Alert';
          final String desc = payload['description']?.toString() ?? '';
          final int sev = int.tryParse(payload['severity']?.toString() ?? '5') ?? 5;
          
          if (reportLat != 0.0 && latitude != null && longitude != null) {
            final distanceMeters = OSRMService.calculateDistance(latitude!, longitude!, reportLat, reportLng);
            if (distanceMeters <= 10000.0) { // 10km radius for general reports
              _addIncomingCommunityReport(type, desc, reportLat, reportLng, sev, distanceMeters);
            }
          }
        } else if (event == 'community_feed_update') {
          // General broadcast of events, even if far away
          final String type = payload['type']?.toString() ?? 'Alert';
          final String msg = payload['message']?.toString() ?? 'Safety alert triggered nearby';
          final double lat = double.tryParse(payload['latitude']?.toString() ?? '0') ?? 0.0;
          final double lon = double.tryParse(payload['longitude']?.toString() ?? '0') ?? 0.0;
          
          _alerts.insert(0, AlertItem(
            id: 'feed_${DateTime.now().millisecondsSinceEpoch}',
            type: type == 'SOS' ? 'SOS' : 'INFO',
            title: '🚨 Community Update 🚨',
            body: msg,
            timestamp: DateTime.now(),
            riskLevel: type == 'SOS' ? 'CRITICAL' : 'MEDIUM',
            latitude: lat != 0.0 ? lat : null,
            longitude: lon != 0.0 ? lon : null,
          ));
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[SafetyProvider] Socket message error: $e');
      }
    });
  }

  void _addCommunitySOSAlert(String name, double lat, double lng, String id, double distance) {
    if (_alerts.any((a) => a.id == 'comm_sos_$id')) return;
    _alerts.insert(0, AlertItem(id: 'comm_sos_$id', type: 'COMMUNITY_SOS', title: '🚨 SOS: $name needs help! 🚨', body: 'Emergency triggered within ${(distance / 1000).toStringAsFixed(1)}km of your location.', timestamp: DateTime.now(), riskLevel: 'CRITICAL', latitude: lat, longitude: lng));
    _pendingSOSAlert = _alerts.first;
    WearableAlertManager().onCommunityAlert('🚨 EMERGENCY NEARBY', '$name needs help nearby!');
    notifyListeners();
  }

  void _addIncomingCommunityReport(String type, String desc, double lat, double lng, int severity, double distance) {
    final reportId = 'comm_report_${DateTime.now().millisecondsSinceEpoch}';
    
    _alerts.insert(0, AlertItem(
      id: reportId,
      type: 'REPORT',
      title: 'Community Alert: $type',
      body: '$desc (${(distance / 1000).toStringAsFixed(1)}km away)',
      timestamp: DateTime.now(),
      riskLevel: severity > 7 ? 'HIGH' : severity > 4 ? 'MEDIUM' : 'LOW',
      latitude: lat,
      longitude: lng,
    ));
    
    notifyListeners();
  }

  void clearPendingSOS() { _pendingSOSAlert = null; notifyListeners(); }

  Future<void> refreshProfile() async {
    await _loadUserProfile();
    if (_userProfile.phone.isNotEmpty) {
      await SocketService().connect(_userProfile.phone);
      _listenToSocket();
    }
    notifyListeners();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(AppConstants.keyUserPhone) ?? '';
    final email = prefs.getString(AppConstants.keyUserEmail) ?? '';
    final identifier = phone.isNotEmpty ? phone : email;
    final savedContactsJson = prefs.getStringList('trusted_contacts_full') ?? [];
    List<GuardianContact> contacts = [];
    if (savedContactsJson.isNotEmpty) {
      contacts = savedContactsJson.map((s) => GuardianContact.fromJson(jsonDecode(s))).toList();
    } else {
      final stringList = prefs.getStringList('trusted_contacts') ?? [];
      contacts = stringList.map((s) => GuardianContact(name: 'Guardian', phone: s)).toList();
    }
    _userProfile = UserProfile(name: prefs.getString(AppConstants.keyUserName) ?? '', phone: phone, trustedContacts: contacts, isComplete: prefs.getBool('@profile_complete') ?? false, isSetupComplete: prefs.getBool('@setup_complete') ?? false);
    if (identifier.isNotEmpty) {
      try {
        final mongo = MongoService();
        if (!mongo.isConnected) await mongo.connect();
        final userDoc = await mongo.getUserByEmail(identifier);
        if (userDoc != null) {
          final mongoName = userDoc['name'] as String? ?? '';
          if (mongoName.isNotEmpty) { _userProfile.name = mongoName; await prefs.setString(AppConstants.keyUserName, mongoName); }
        }
        List<Map<String, dynamic>> contactsData = await mongo.getContactsByEmail(identifier);
        if (contactsData.isNotEmpty) {
          final mongoContacts = contactsData.where((data) => (data['phone'] as String? ?? '').isNotEmpty).map((data) => GuardianContact(name: data['name'] as String? ?? 'Guardian', phone: data['phone'] as String? ?? '')).toList();
          if (mongoContacts.isNotEmpty) {
            _userProfile.trustedContacts = mongoContacts;
            await prefs.setStringList('trusted_contacts_full', mongoContacts.map((c) => jsonEncode(c.toJson())).toList());
          }
        }
      } catch (e) { debugPrint('[SafetyProvider] Deep sync error: $e'); }
    }
    _trustedContacts = _userProfile.trustedContacts;
    _inputContacts = _trustedContacts.isNotEmpty ? List.from(_trustedContacts) : [GuardianContact(name: '', phone: '')];
  }

  Future<void> clearProfile() async { _userProfile = UserProfile(); final prefs = await SharedPreferences.getInstance(); await prefs.clear(); _trustedContacts = []; _inputContacts = [GuardianContact(name: '', phone: '')]; notifyListeners(); }

  Future<void> updateUserProfile(UserProfile profile) async {
    _userProfile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUserName, profile.name);
    await prefs.setString(AppConstants.keyUserPhone, profile.phone);
    await prefs.setBool('@profile_complete', profile.isComplete);
    _trustedContacts = profile.trustedContacts;
    notifyListeners();
  }

  void setInputContacts(List<GuardianContact> contacts) { _inputContacts = contacts; notifyListeners(); }

  Future<void> saveTrustedContacts() async {
    final validContacts = _inputContacts.where((c) => c.phone.trim().length >= 10).toList();
    _trustedContacts = validContacts;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('trusted_contacts_full', validContacts.map((c) => jsonEncode(c.toJson())).toList());
    _userProfile = _userProfile.copyWith(trustedContacts: validContacts);
    notifyListeners();
  }

  Future<void> triggerSOSFlow() async {
    if (_sosProvider == null) return;
    final String msg = (latitude != null && longitude != null) ? '🚨 EMERGENCY SOS 🚨\nI need help! Live location: https://www.google.com/maps?q=$latitude,$longitude' : '🚨 EMERGENCY SOS 🚨\nI need help!';
    final List<String> phoneNumbers = _trustedContacts.map((c) => c.phone).toList();
    await _sosProvider!.triggerSOS(customContacts: phoneNumbers.isNotEmpty ? phoneNumbers : null, customMessage: msg);
    _alerts.insert(0, AlertItem(id: DateTime.now().millisecondsSinceEpoch.toString(), type: 'SOS', title: 'SOS Activated', body: 'Emergency SOS sent to guardians.', timestamp: DateTime.now(), riskLevel: riskLabel));
    notifyListeners();
  }

  Future<void> confirmSafe() async {
    if (_sosProvider != null) {
      await _sosProvider!.cancelSOS();
      final msg = 'SAFE: I am safe now. My location: $_readableAddress';
      final List<String> phoneNumbers = _trustedContacts.map((c) => c.phone).toList();
      SMSService().sendBulkSMS(phoneNumbers: phoneNumbers, message: msg);
      _alerts.insert(0, AlertItem(id: DateTime.now().millisecondsSinceEpoch.toString(), type: 'SAFE', title: 'Safe Confirmed', body: 'Safety confirmed.', timestamp: DateTime.now()));
    }
    notifyListeners();
  }

  void stopRecording() { notifyListeners(); }
  void setVoiceListening(bool enabled) { _voiceProvider?.toggleVoiceTrigger(enabled); notifyListeners(); }
  void setShakeTrigger(bool enabled) { _shakeSosProvider?.toggleEnabled(enabled); notifyListeners(); }
  void stopSiren() { _zoneService?.stopSiren(); notifyListeners(); }
  void startDemoSiren() { _zoneService?.startDemoSiren(); notifyListeners(); }
  void clearAlerts() { _alerts.clear(); notifyListeners(); }
  void removeAlert(String id) { _alerts.removeWhere((a) => a.id == id); notifyListeners(); }
  void refreshSOSState() { notifyListeners(); }
  
  Future<bool> submitCommunityReport(String type, String desc, int severity) async {
    try {
      if (latitude == null || longitude == null) {
        debugPrint('[Safety] Community report failed: Location is null');
        return false;
      }
      
      final success = await _communityProvider?.submitReport(
        phone: _userProfile.phone,
        latitude: latitude!,
        longitude: longitude!,
        incidentType: type,
        description: desc,
        severity: severity,
      );
      
      if (success == true) {
        _alerts.insert(0, AlertItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 'REPORT',
          title: type,
          body: desc,
          timestamp: DateTime.now(),
          riskLevel: severity > 7 ? 'HIGH' : severity > 4 ? 'MEDIUM' : 'LOW',
          latitude: latitude!,
          longitude: longitude!,
        ));
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Safety] Community report exception: $e');
      return false;
    }
  }

  @override
  void dispose() { _sosProvider?.removeListener(_onSOSStateChanged); _durationTimer?.cancel(); super.dispose(); }
}