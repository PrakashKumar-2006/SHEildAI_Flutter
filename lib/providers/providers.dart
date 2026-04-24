<<<<<<< HEAD
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/localization.dart';
import '../core/app_theme.dart';
=======
import 'dart:async';
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
>>>>>>> 54e68e5 (Hardened ML integration, migrated to Google Maps, and fixed SOS background SMS with AGP 8 fix)

// ─── Theme Provider ────────────────────────────────────────────────────────────
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
<<<<<<< HEAD

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

=======
  bool get isDarkMode => _isDarkMode;
  ThemeProvider() { _loadTheme(); }
>>>>>>> 54e68e5 (Hardened ML integration, migrated to Google Maps, and fixed SOS background SMS with AGP 8 fix)
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getString('@app_theme') == 'dark';
    notifyListeners();
  }
<<<<<<< HEAD

=======
>>>>>>> 54e68e5 (Hardened ML integration, migrated to Google Maps, and fixed SOS background SMS with AGP 8 fix)
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('@app_theme', _isDarkMode ? 'dark' : 'light');
    notifyListeners();
  }
<<<<<<< HEAD

=======
>>>>>>> 54e68e5 (Hardened ML integration, migrated to Google Maps, and fixed SOS background SMS with AGP 8 fix)
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
<<<<<<< HEAD

  String get language => _language;

  LanguageProvider() {
    _loadLanguage();
  }

=======
  String get language => _language;
  LanguageProvider() { _loadLanguage(); }
>>>>>>> 54e68e5 (Hardened ML integration, migrated to Google Maps, and fixed SOS background SMS with AGP 8 fix)
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('@app_language') ?? 'en';
    notifyListeners();
  }
<<<<<<< HEAD

=======
>>>>>>> 54e68e5 (Hardened ML integration, migrated to Google Maps, and fixed SOS background SMS with AGP 8 fix)
  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('@app_language', lang);
    notifyListeners();
  }
<<<<<<< HEAD

  String t(String key) => AppStrings.get(key, _language);
}

// ─── User Profile Model ────────────────────────────────────────────────────────
class UserProfile {
  String name;
  String phone;
  List<String> trustedContacts;
  bool isComplete;
  bool isSetupComplete;

  UserProfile({
    this.name = '',
    this.phone = '',
    this.trustedContacts = const [],
    this.isComplete = false,
    this.isSetupComplete = false,
  });

  UserProfile copyWith({
    String? name,
    String? phone,
    List<String>? trustedContacts,
    bool? isComplete,
    bool? isSetupComplete,
  }) {
    return UserProfile(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      trustedContacts: trustedContacts ?? this.trustedContacts,
      isComplete: isComplete ?? this.isComplete,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
    );
  }
}

// ─── Alert Item Model ──────────────────────────────────────────────────────────
class AlertItem {
  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? riskLevel;

  AlertItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.riskLevel,
  });
}

// ─── Safety Provider ───────────────────────────────────────────────────────────
=======
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
>>>>>>> 54e68e5 (Hardened ML integration, migrated to Google Maps, and fixed SOS background SMS with AGP 8 fix)
class SafetyProvider extends ChangeNotifier {
  bool _isAppReady = false;
  UserProfile _userProfile = UserProfile();
  List<String> _trustedContacts = [];
  List<String> _inputContacts = [''];
<<<<<<< HEAD
  bool _isSOSActive = false;
  String _sosState = 'IDLE'; // IDLE, SOS_ACTIVE, RECORDING, RECOVERING
  String? _sosSessionId;
  DateTime? _sosSessionStart;
  int _activeSessionDuration = 0;
  int _recordingTimeLeft = 120;
  String _riskLabel = 'SAFE';
  int _riskScore = 12;
  String _riskZone = 'Bhopal, Madhya Pradesh';
  bool _isSafetyModeActive = false;
  List<AlertItem> _alerts = [];

  // Mock location
  double _latitude = 23.2599;
  double _longitude = 77.4126;
=======
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
>>>>>>> 54e68e5 (Hardened ML integration, migrated to Google Maps, and fixed SOS background SMS with AGP 8 fix)

  bool get isAppReady => _isAppReady;
  UserProfile get userProfile => _userProfile;
  List<String> get trustedContacts => _trustedContacts;
  List<String> get inputContacts => _inputContacts;
<<<<<<< HEAD
  bool get isSOSActive => _isSOSActive;
  String get sosState => _sosState;
  String? get sosSessionId => _sosSessionId;
  DateTime? get sosSessionStart => _sosSessionStart;
  int get activeSessionDuration => _activeSessionDuration;
  int get recordingTimeLeft => _recordingTimeLeft;
  String get riskLabel => _riskLabel;
  int get riskScore => _riskScore;
  String get riskZone => _riskZone;
  bool get isSafetyModeActive => _isSafetyModeActive;
  List<AlertItem> get alerts => _alerts;
  double get latitude => _latitude;
  double get longitude => _longitude;

  SafetyProvider() {
    _init();
=======
  bool get isSOSActive => _sosProvider?.isSOSActive ?? false;
  String get sosState => isSOSActive ? 'SOS_ACTIVE' : 'IDLE';
  String? get sosSessionId => _sosProvider?.activeSOS?.id;
  DateTime? get sosSessionStart => _sosProvider?.activeSOS?.timestamp;
  
  int get activeSessionDuration {
    if (sosSessionStart == null) return 0;
    return DateTime.now().difference(sosSessionStart!).inSeconds;
  }
  
  int get recordingTimeLeft => 120 - (activeSessionDuration % 120);
  
  // ML Fields
  String get riskLabel => (_mlProvider?.riskPrediction?['risk_label'] ?? 'SAFE').toString().toUpperCase();
  int get riskScore => (_mlProvider?.riskPrediction?['risk_score'] ?? 0).toInt();
  String get riskColor => (_mlProvider?.riskPrediction?['risk_color'] ?? '#43A047').toString();
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

      // Update ML if moved significantly or every 5 mins
      final now = DateTime.now();
      if (_lastMLUpdate == null || now.difference(_lastMLUpdate!).inMinutes >= 5) {
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
>>>>>>> 54e68e5 (Hardened ML integration, migrated to Google Maps, and fixed SOS background SMS with AGP 8 fix)
  }

  Future<void> _init() async {
    await _loadUserProfile();
    _isAppReady = true;
    notifyListeners();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
<<<<<<< HEAD
    final name = prefs.getString('@user_name') ?? '';
    final phone = prefs.getString('@user_phone') ?? '';
    final contacts = prefs.getStringList('@trusted_contacts') ?? [];
    final isComplete = prefs.getBool('@profile_complete') ?? false;
    final isSetupComplete = prefs.getBool('@setup_complete') ?? false;
    _userProfile = UserProfile(
      name: name,
      phone: phone,
      trustedContacts: contacts,
      isComplete: isComplete,
      isSetupComplete: isSetupComplete,
    );
    _trustedContacts = contacts;
    if (_trustedContacts.isNotEmpty) {
      _inputContacts = List.from(_trustedContacts);
    }
=======
    _userProfile = UserProfile(
      name: prefs.getString('@user_name') ?? '',
      phone: prefs.getString('@user_phone') ?? '',
      trustedContacts: prefs.getStringList('@trusted_contacts') ?? [],
      isComplete: prefs.getBool('@profile_complete') ?? false,
      isSetupComplete: prefs.getBool('@setup_complete') ?? false,
    );
    _trustedContacts = _userProfile.trustedContacts;
    _inputContacts = _trustedContacts.isNotEmpty ? List.from(_trustedContacts) : [''];
>>>>>>> 54e68e5 (Hardened ML integration, migrated to Google Maps, and fixed SOS background SMS with AGP 8 fix)
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    _userProfile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('@user_name', profile.name);
    await prefs.setString('@user_phone', profile.phone);
    await prefs.setStringList('@trusted_contacts', profile.trustedContacts);
    await prefs.setBool('@profile_complete', profile.isComplete);
    await prefs.setBool('@setup_complete', profile.isSetupComplete);
    _trustedContacts = profile.trustedContacts;
    notifyListeners();
  }

<<<<<<< HEAD
  void setInputContacts(List<String> contacts) {
    _inputContacts = contacts;
    notifyListeners();
  }

  Future<void> saveTrustedContacts() async {
    final validContacts = _inputContacts.where((c) => c.trim().length == 10).toList();
=======
  void setInputContacts(List<String> contacts) { _inputContacts = contacts; notifyListeners(); }

  Future<void> saveTrustedContacts() async {
    final validContacts = _inputContacts.where((c) => c.trim().length >= 10).toList();
>>>>>>> 54e68e5 (Hardened ML integration, migrated to Google Maps, and fixed SOS background SMS with AGP 8 fix)
    _trustedContacts = validContacts;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('@trusted_contacts', validContacts);
    _userProfile = _userProfile.copyWith(trustedContacts: validContacts);
    notifyListeners();
  }

  Future<void> triggerSOSFlow() async {
<<<<<<< HEAD
    _isSOSActive = true;
    _sosState = 'SOS_ACTIVE';
    _sosSessionId = DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase();
    _sosSessionStart = DateTime.now();
    _activeSessionDuration = 0;
    _recordingTimeLeft = 120;

    // Add alert to feed
    _alerts.insert(0, AlertItem(
      id: _sosSessionId!,
      type: 'SOS',
      title: 'SOS Activated',
      body: 'Emergency SOS session started at ${_riskZone}.',
      timestamp: DateTime.now(),
      riskLevel: _riskLabel,
    ));

=======
    if (_sosProvider != null) {
      final msg = 'EMERGENCY: I need help! My location: $_readableAddress (https://maps.google.com/?q=$latitude,$longitude)';
      await _sosProvider!.triggerSOS(customContacts: _trustedContacts, customMessage: msg);
      _alerts.insert(0, AlertItem(id: DateTime.now().millisecondsSinceEpoch.toString(), type: 'SOS', title: 'SOS Activated', body: 'Emergency SOS sent to guardians.', timestamp: DateTime.now(), riskLevel: riskLabel));
    }
>>>>>>> 54e68e5 (Hardened ML integration, migrated to Google Maps, and fixed SOS background SMS with AGP 8 fix)
    notifyListeners();
  }

  Future<void> confirmSafe() async {
<<<<<<< HEAD
    _isSOSActive = false;
    _sosState = 'IDLE';
    _sosSessionId = null;
    _sosSessionStart = null;
    _activeSessionDuration = 0;
    _recordingTimeLeft = 120;

    // Add safe alert
    _alerts.insert(0, AlertItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'SAFE',
      title: 'Safe Confirmed',
      body: 'User confirmed safety. SOS session ended.',
      timestamp: DateTime.now(),
    ));

    notifyListeners();
  }

  void stopRecording() {
    _sosState = 'RECOVERING';
    notifyListeners();
  }

  void setVoiceListening(bool enabled) {
    _isSafetyModeActive = enabled;
    notifyListeners();
  }

  void refreshSOSState() {
    notifyListeners();
  }

  Future<bool> submitCommunityReport(String type, String desc, int severity) async {
    _alerts.insert(0, AlertItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'REPORT',
      title: type,
      body: desc,
      timestamp: DateTime.now(),
      riskLevel: severity > 7 ? 'HIGH' : severity > 4 ? 'MEDIUM' : 'LOW',
    ));
    notifyListeners();
    return true;
  }
=======
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
    _alerts.insert(0, AlertItem(id: DateTime.now().millisecondsSinceEpoch.toString(), type: 'REPORT', title: type, body: desc, timestamp: DateTime.now(), riskLevel: severity > 7 ? 'HIGH' : severity > 4 ? 'MEDIUM' : 'LOW'));
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }
>>>>>>> 54e68e5 (Hardened ML integration, migrated to Google Maps, and fixed SOS background SMS with AGP 8 fix)
}
