import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/localization.dart';
import '../core/app_theme.dart';

// ─── Theme Provider ────────────────────────────────────────────────────────────
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

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

  LanguageProvider() {
    _loadLanguage();
  }

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
class SafetyProvider extends ChangeNotifier {
  bool _isAppReady = false;
  UserProfile _userProfile = UserProfile();
  List<String> _trustedContacts = [];
  List<String> _inputContacts = [''];
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

  bool get isAppReady => _isAppReady;
  UserProfile get userProfile => _userProfile;
  List<String> get trustedContacts => _trustedContacts;
  List<String> get inputContacts => _inputContacts;
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
  }

  Future<void> _init() async {
    await _loadUserProfile();
    _isAppReady = true;
    notifyListeners();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
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

  void setInputContacts(List<String> contacts) {
    _inputContacts = contacts;
    notifyListeners();
  }

  Future<void> saveTrustedContacts() async {
    final validContacts = _inputContacts.where((c) => c.trim().length == 10).toList();
    _trustedContacts = validContacts;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('@trusted_contacts', validContacts);
    _userProfile = _userProfile.copyWith(trustedContacts: validContacts);
    notifyListeners();
  }

  Future<void> triggerSOSFlow() async {
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

    notifyListeners();
  }

  Future<void> confirmSafe() async {
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
}
