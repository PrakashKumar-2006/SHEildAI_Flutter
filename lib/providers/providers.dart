import 'dart:async';
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
import '../core/services/zone_service.dart';
import '../features/voice/presentation/providers/voice_provider.dart';
import '../features/sos/domain/models/sos_model.dart';
import '../core/models/zone_model.dart';
import '../core/services/sms_service.dart';
import '../core/services/api_service.dart';

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
class UserProfile {
  String name; String phone; List<String> trustedContacts; bool isComplete; bool isSetupComplete;
  UserProfile({this.name = '', this.phone = '', this.trustedContacts = const [], this.isComplete = false, this.isSetupComplete = false});
  UserProfile copyWith({String? name, String? phone, List<String>? trustedContacts, bool? isComplete, bool? isSetupComplete}) {
    return UserProfile(name: name ?? this.name, phone: phone ?? this.phone, trustedContacts: trustedContacts ?? this.trustedContacts, isComplete: isComplete ?? this.isComplete, isSetupComplete: isSetupComplete ?? this.isSetupComplete);
  }
}

class AlertItem {
  final String id; final String type; final String title; final String body; final DateTime timestamp; final String? riskLevel;
  AlertItem({required this.id, required this.type, required this.title, required this.body, required this.timestamp, this.riskLevel});
}

// ─── Safety Provider (Bridge) ───────────────────────────────────────────────────
class SafetyProvider extends ChangeNotifier {
  bool _isAppReady = false;
  UserProfile _userProfile = UserProfile();
  List<String> _trustedContacts = [];
  List<String> _inputContacts = [''];
  List<AlertItem> _alerts = [];
  String _readableAddress = 'Scanning location...';
  Timer? _durationTimer;
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

  bool get isAppReady => _isAppReady;
  UserProfile get userProfile => _userProfile;
  List<String> get trustedContacts => _trustedContacts;
  List<String> get inputContacts => _inputContacts;
  bool get isSOSActive => _sosProvider?.isSOSActive ?? false;
  String get sosState => isSOSActive ? 'SOS_ACTIVE' : 'IDLE';
  String? get sosSessionId => _sosProvider?.activeSOS?.id;
  DateTime? get sosSessionStart => _sosProvider?.activeSOS?.timestamp;
  
  int get activeSessionDuration {
    if (sosSessionStart == null) return 0;
    return DateTime.now().difference(sosSessionStart!).inSeconds;
  }
  
  int get recordingTimeLeft => 120 - (activeSessionDuration % 120);
  
  // ML Fields (Mapped to backend thresholds)
  String get riskLabel {
    final score = riskScore;
    if (score <= 25) return 'SAFE';
    if (score <= 50) return 'MEDIUM';
    if (score <= 75) return 'HIGH';
    return 'CRITICAL';
  }
  int get riskScore => (_mlProvider?.riskPrediction?['risk_score'] ?? 0).toInt();
  String get riskColor {
    final score = riskScore;
    if (score <= 25) return '#43A047'; // Green
    if (score <= 50) return '#FBC02D'; // Yellow/Orange
    if (score <= 75) return '#F57C00'; // Orange
    return '#D32F2F'; // Red
  }
  List<String> get riskAlerts => List<String>.from(_mlProvider?.riskPrediction?['alerts'] ?? []);
  Map<String, dynamic>? get bestTravelTime => _mlProvider?.bestTravelTime;
  Map<String, dynamic>? get forecast => _mlProvider?.forecast;
  
  String get readableAddress => _readableAddress;
  
  bool get isSafetyModeActive => _voiceProvider?.isEnabled ?? false;
  bool get isSirenPlaying => _zoneService?.isSirenPlaying ?? false;
  List<AlertItem> get alerts => _alerts;
  double get latitude => _locationProvider?.currentLocation?.latitude ?? 22.7196;
  double get longitude => _locationProvider?.currentLocation?.longitude ?? 75.8577;
  List<ZoneModel> get zones => _zoneService?.zones ?? [];

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

  void update(SOSProvider sos, LocationProvider loc, MLProvider ml, ZoneService zone, VoiceProvider voice) {
    _sosProvider = sos;
    _locationProvider = loc;
    _mlProvider = ml;
    _zoneService = zone;
    _voiceProvider = voice;
    
    _syncWithLocation();
  }

  void _syncWithLocation() {
    if (_locationProvider?.currentLocation != null) {
      final lat = _locationProvider!.currentLocation!.latitude;
      final lon = _locationProvider!.currentLocation!.longitude;
      
      // Update Address
      LocationService().getAddressFromLatLng(lat, lon).then((addr) {
        if (_readableAddress != addr) {
          _readableAddress = addr;
          notifyListeners();
        }
      });

      // Update ML if moved significantly or every 1 min (Optimized for testing)
      final now = DateTime.now();
      if (_lastMLUpdate == null || now.difference(_lastMLUpdate!).inMinutes >= 1) {
        _lastMLUpdate = now;
        _mlProvider?.predictRisk(
          lat: lat, 
          lon: lon, 
          hour: now.hour, 
          month: now.month,
          battery: _currentBatteryLevel,
          internet: _hasInternet,
          isWeekend: (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) ? 1 : 0,
        );
        _mlProvider?.getForecast(
          lat: lat, 
          lon: lon, 
          currentHour: now.hour, 
          month: now.month,
          isWeekend: (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) ? 1 : 0,
        );
        _mlProvider?.getBestTravelTime(
          lat: lat, 
          lon: lon, 
          month: now.month,
          isWeekend: (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) ? 1 : 0,
        );
      }
    }
  }

  Future<void> _init() async {
    await _loadUserProfile();
    _isAppReady = true;
    notifyListeners();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _userProfile = UserProfile(
      name: prefs.getString(AppConstants.keyUserName) ?? '',
      phone: prefs.getString(AppConstants.keyUserPhone) ?? '',
      trustedContacts: prefs.getStringList('@trusted_contacts') ?? [],
      isComplete: prefs.getBool('@profile_complete') ?? false,
      isSetupComplete: prefs.getBool('@setup_complete') ?? false,
    );
    _trustedContacts = _userProfile.trustedContacts;
    _inputContacts = _trustedContacts.isNotEmpty ? List.from(_trustedContacts) : [''];
  }

  Future<void> clearProfile() async {
    _userProfile = UserProfile();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all saved settings
    _trustedContacts = [];
    _inputContacts = [''];
    notifyListeners();
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    _userProfile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUserName, profile.name);
    await prefs.setString(AppConstants.keyUserPhone, profile.phone);
    await prefs.setStringList('@trusted_contacts', profile.trustedContacts);
    await prefs.setBool('@profile_complete', profile.isComplete);
    await prefs.setBool('@setup_complete', profile.isSetupComplete);
    _trustedContacts = profile.trustedContacts;
    notifyListeners();
  }

  void setInputContacts(List<String> contacts) { _inputContacts = contacts; notifyListeners(); }

  Future<void> saveTrustedContacts() async {
    final validContacts = _inputContacts.where((c) => c.trim().length >= 10).toList();
    _trustedContacts = validContacts;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('@trusted_contacts', validContacts);
    _userProfile = _userProfile.copyWith(trustedContacts: validContacts);
    notifyListeners();
  }

  Future<void> triggerSOSFlow() async {
    if (_sosProvider != null) {
      final msg = 'EMERGENCY: I need help! My location: $_readableAddress (https://maps.google.com/?q=$latitude,$longitude)';
      await _sosProvider!.triggerSOS(customContacts: _trustedContacts, customMessage: msg);
      _alerts.insert(0, AlertItem(id: DateTime.now().millisecondsSinceEpoch.toString(), type: 'SOS', title: 'SOS Activated', body: 'Emergency SOS sent to guardians.', timestamp: DateTime.now(), riskLevel: riskLabel));
    }
    notifyListeners();
  }

  Future<void> confirmSafe() async {
    if (_sosProvider != null) {
      await _sosProvider!.cancelSOS();
      final msg = 'SAFE: I am safe now. Thank you for your support. My location: $_readableAddress';
      SMSService().sendBulkSMS(phoneNumbers: _trustedContacts, message: msg, direct: true);
      _alerts.insert(0, AlertItem(id: DateTime.now().millisecondsSinceEpoch.toString(), type: 'SAFE', title: 'Safe Confirmed', body: 'Safety confirmed. Guardians notified.', timestamp: DateTime.now()));
    }
    notifyListeners();
  }

  void stopRecording() { notifyListeners(); }

  void setVoiceListening(bool enabled) { 
    _voiceProvider?.toggleVoiceTrigger(enabled);
    notifyListeners(); 
  }

  void stopSiren() {
    _zoneService?.stopSiren();
    notifyListeners();
  }

  void refreshSOSState() { notifyListeners(); }
  
  Future<bool> submitCommunityReport(String type, String desc, int severity) async {
    try {
      final success = await ApiService.submitCommunityReport(
        _userProfile.phone,
        latitude,
        longitude,
        type,
        desc,
        severity,
        anonymous: true,
      );
      
      if (success != null) {
        _alerts.insert(0, AlertItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(), 
          type: 'REPORT', 
          title: type, 
          body: desc, 
          timestamp: DateTime.now(), 
          riskLevel: severity > 7 ? 'HIGH' : severity > 4 ? 'MEDIUM' : 'LOW'
        ));
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[Safety] Community report error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }
}
