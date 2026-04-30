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
import '../features/sos/domain/models/sos_model.dart';
import '../core/models/zone_model.dart';
import '../core/services/sms_service.dart';
import '../core/services/api_service.dart' as api;
import '../features/community/presentation/providers/community_provider.dart';
import '../core/services/socket_service.dart';
import '../core/services/osrm_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/mongo_service.dart';

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
  CommunityProvider? _communityProvider;

  bool get isAppReady => _isAppReady;
  UserProfile get userProfile => _userProfile;
  List<GuardianContact> get trustedContacts => _trustedContacts;
  List<GuardianContact> get inputContacts => _inputContacts;
  bool get isSOSActive => _sosProvider?.isSOSActive ?? false;

  /// Returns a granular state string for the SOS screen's session sub-panels.
  /// Maps the native state machine state so the UI can show the correct panel
  /// (recording countdown, initialising SOS, evidence done, etc.).
  String get sosState {
    final native = _sosProvider?.nativeState;
    if (native == SOSNativeState.recordingAudio ||
        native == SOSNativeState.recordingVideo) {
      return 'RECORDING';
    }
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
  
  // ML Fields (Mapped to backend thresholds)
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

  String get riskColor {
    if (!(_zoneService?.isDataAvailable ?? false)) return '#94A3B8'; // Slate/Grey for N/A
    
    final score = riskScore;
    if (_zoneService?.currentZone?.id == 'outside' || score <= 25) return '#43A047'; // Green
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
  double? get latitude => _locationProvider?.currentLocation?.latitude;
  double? get longitude => _locationProvider?.currentLocation?.longitude;
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

  // ─── SOSProvider listener ─────────────────────────────────────────────────

  /// Called every time SOSProvider notifies its listeners (native state change,
  /// Flutter SOS start/stop, etc.).  Propagates changes to all SafetyProvider
  /// listeners so the navbar SOS button and SOS screen rebuild immediately.
  void _onSOSStateChanged() => notifyListeners();

  void update(SOSProvider sos, LocationProvider loc, MLProvider ml, ZoneService zone, VoiceProvider voice, CommunityProvider community) {
    // Re-subscribe only when the SOSProvider instance actually changes.
    // ProxyProvider may rebuild SafetyProvider with the same instance, so
    // we guard against redundant remove+add to keep the listener list clean.
    if (_sosProvider != sos) {
      _sosProvider?.removeListener(_onSOSStateChanged);
      _sosProvider = sos;
      _sosProvider?.addListener(_onSOSStateChanged);
    }

    _locationProvider = loc;
    _mlProvider = ml;
    _zoneService = zone;
    _voiceProvider = voice;
    _communityProvider = community;

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
        debugPrint('[Safety] Refreshing Safety Intelligence (Parallel) for: $lat, $lon');
        
        // Fire all ML and Community requests in parallel to significantly reduce total load time
        Future.wait([
          _mlProvider?.predictRisk(
            lat: lat, 
            lon: lon, 
            hour: now.hour, 
            month: now.month,
            battery: _currentBatteryLevel,
            internet: _hasInternet,
            isWeekend: (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) ? 1 : 0,
          ) ?? Future.value(),
          _mlProvider?.getForecast(
            lat: lat, 
            lon: lon, 
            currentHour: now.hour, 
            month: now.month,
            isWeekend: (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) ? 1 : 0,
          ) ?? Future.value(),
          _mlProvider?.getBestTravelTime(
            lat: lat, 
            lon: lon, 
            month: now.month,
            isWeekend: (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) ? 1 : 0,
          ) ?? Future.value(),
          _communityProvider?.loadNearbyReports(
            latitude: lat,
            longitude: lon,
            radiusKm: 10,
          ) ?? Future.value(),
        ]);
      }
    }
  }

  Future<void> _init() async {
    await _loadUserProfile();
    if (_userProfile.phone.isNotEmpty) {
      // Connect to socket for real-time community alerts
      await SocketService().connect(_userProfile.phone);
      _listenToSocket();
    }
    _isAppReady = true;
    notifyListeners();
  }

  void _listenToSocket() {
    SocketService().messageStream.listen((msg) {
      try {
        final event = msg['event'];
        final data = msg; // In the new SocketService, msg contains all payload data + event name
        
        if (event == 'sos_broadcast') {
          final double victimLat = (data['latitude'] as num).toDouble();
          final double victimLng = (data['longitude'] as num).toDouble();
          final String victimName = data['name'] ?? 'Someone';
          final String sosId = data['sosId'] ?? DateTime.now().millisecondsSinceEpoch.toString();
          
          if (latitude != null && longitude != null) {
            // Calculate distance using OSRMService's Haversine formula
            final distanceMeters = OSRMService.calculateDistance(latitude!, longitude!, victimLat, victimLng);
            if (distanceMeters <= 5000.0) { // 5km radius
              _addCommunitySOSAlert(victimName, victimLat, victimLng, sosId, distanceMeters);
            }
          }
        }
      } catch (e) {
        debugPrint('[SafetyProvider] Socket message error: $e');
      }
    });
  }

  void _addCommunitySOSAlert(String name, double lat, double lng, String id, double distance) {
    // Check if we already have this alert to avoid duplicates
    if (_alerts.any((a) => a.id == 'comm_sos_$id')) return;

    _alerts.insert(0, AlertItem(
      id: 'comm_sos_$id',
      type: 'COMMUNITY_SOS',
      title: '🚨 SOS: $name needs help! 🚨',
      body: 'Emergency triggered within ${(distance / 1000).toStringAsFixed(1)}km of your location.',
      timestamp: DateTime.now(),
      riskLevel: 'CRITICAL',
      latitude: lat,
      longitude: lng,
    ));
    
    // Show system notification
    NotificationService().showCommunitySOSNotification(
      name: name,
      distanceMeters: distance,
    );
    
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    await _loadUserProfile();
    notifyListeners();
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Get identifiers
    final phone = prefs.getString(AppConstants.keyUserPhone) ?? '';
    final email = prefs.getString(AppConstants.keyUserEmail) ?? '';
    
    // Fallback: If email is missing, use phone (for legacy sessions)
    final identifier = email.isNotEmpty ? email : phone;
    
    // 2. Load contacts from local storage first (JSON)
    final savedContactsJson = prefs.getStringList('trusted_contacts_full') ?? [];
    List<GuardianContact> contacts = [];
    if (savedContactsJson.isNotEmpty) {
      contacts = savedContactsJson.map((s) => GuardianContact.fromJson(jsonDecode(s))).toList();
    } else {
      // Fallback to basic string list if full list is missing
      final stringList = prefs.getStringList('trusted_contacts') ?? [];
      contacts = stringList.map((s) => GuardianContact(name: 'Guardian', phone: s)).toList();
    }

    // 2. Load basic profile
    _userProfile = UserProfile(
      name: prefs.getString(AppConstants.keyUserName) ?? '',
      phone: phone,
      trustedContacts: contacts,
      isComplete: prefs.getBool('@profile_complete') ?? false,
      isSetupComplete: prefs.getBool('@setup_complete') ?? false,
    );

    // 3. Deep sync from MongoDB (Always do this to get latest names/phones)
    if (identifier.isNotEmpty) {
      try {
        final mongo = MongoService();
        if (!mongo.isConnected) await mongo.connect();
        
        // Fetch User Doc for name/profile info
        final userDoc = await mongo.getUserByEmail(identifier);
        if (userDoc != null) {
          final mongoName = userDoc['name'] as String? ?? '';
          final mongoPhone = userDoc['phone'] as String? ?? '';
          // Always prefer MongoDB data — it is the source of truth
          if (mongoName.isNotEmpty) {
            _userProfile.name = mongoName;
            await prefs.setString(AppConstants.keyUserName, mongoName);
          }
          if (mongoPhone.isNotEmpty && _userProfile.phone.isEmpty) {
            _userProfile.phone = mongoPhone;
            await prefs.setString(AppConstants.keyUserPhone, mongoPhone);
          }
        }

        // Fetch from emergency_contacts collection for full details
        List<Map<String, dynamic>> contactsData = await mongo.getContactsByEmail(identifier);
        
        // Also try by phone if email-based lookup returned nothing
        if (contactsData.isEmpty && phone.isNotEmpty && phone != identifier) {
          contactsData = await mongo.getContactsByEmail(phone);
        }
        
        if (contactsData.isNotEmpty) {
          final mongoContacts = contactsData
            .where((data) => (data['phone'] as String? ?? '').isNotEmpty)
            .map((data) => GuardianContact(
              name: data['name'] as String? ?? 'Guardian',
              phone: data['phone'] as String? ?? '',
            )).toList();
          
          if (mongoContacts.isNotEmpty) {
            _userProfile.trustedContacts = mongoContacts;
            
            // Save to local storage
            await prefs.setStringList('trusted_contacts_full', 
              mongoContacts.map((c) => jsonEncode(c.toJson())).toList());
            await prefs.setStringList('trusted_contacts', 
              mongoContacts.map((c) => c.phone).toList());
              
            debugPrint('[SafetyProvider] Deep synced ${mongoContacts.length} contacts from MongoDB');
          }
        }
      } catch (e) {
        debugPrint('[SafetyProvider] Deep sync error: $e');
      }
    }
    
    _trustedContacts = _userProfile.trustedContacts;
    _inputContacts = _trustedContacts.isNotEmpty 
      ? List.from(_trustedContacts) 
      : [GuardianContact(name: '', phone: '')];
  }

  Future<void> clearProfile() async {
    _userProfile = UserProfile();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all saved settings
    _trustedContacts = [];
    _inputContacts = [GuardianContact(name: '', phone: '')];
    notifyListeners();
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    _userProfile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUserName, profile.name);
    await prefs.setString(AppConstants.keyUserPhone, profile.phone);
    await prefs.setStringList('trusted_contacts_full', 
      profile.trustedContacts.map((c) => jsonEncode(c.toJson())).toList());
    await prefs.setStringList('trusted_contacts', 
      profile.trustedContacts.map((c) => c.phone).toList());
    await prefs.setBool('@profile_complete', profile.isComplete);
    await prefs.setBool('@setup_complete', profile.isSetupComplete);
    _trustedContacts = profile.trustedContacts;
    
    // Sync to MongoDB so the change is persisted across logins
    final email = prefs.getString(AppConstants.keyUserEmail) ?? '';
    if (email.isNotEmpty) {
      try {
        final mongo = MongoService();
        if (!mongo.isConnected) await mongo.connect();
        final updates = <String, dynamic>{};
        if (profile.name.isNotEmpty) updates['name'] = profile.name;
        if (profile.phone.isNotEmpty) updates['phone'] = profile.phone;
        if (updates.isNotEmpty) {
          await mongo.updateUser(email, updates);
          debugPrint('[SafetyProvider] Profile synced to MongoDB: $updates');
        }
      } catch (e) {
        debugPrint('[SafetyProvider] Failed to sync profile to MongoDB: $e');
      }
    }
    
    notifyListeners();
  }

  void setInputContacts(List<GuardianContact> contacts) { _inputContacts = contacts; notifyListeners(); }

  Future<void> saveTrustedContacts() async {
    final validContacts = _inputContacts.where((c) => c.phone.trim().length >= 10).toList();
    
    // Compute which phones were removed so we can delete them from MongoDB
    final oldPhones = _trustedContacts.map((c) => c.phone).toSet();
    final newPhones = validContacts.map((c) => c.phone).toSet();
    final deletedPhones = oldPhones.difference(newPhones);
    
    _trustedContacts = validContacts;
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setStringList('trusted_contacts_full', 
      validContacts.map((c) => jsonEncode(c.toJson())).toList());
    await prefs.setStringList('trusted_contacts', 
      validContacts.map((c) => c.phone).toList());
      
    _userProfile = _userProfile.copyWith(trustedContacts: validContacts);
    
    // Cloud sync
    final email = prefs.getString(AppConstants.keyUserEmail) ?? _userProfile.phone;

    if (email.isNotEmpty) {
      try {
        final mongo = MongoService();
        if (!mongo.isConnected) await mongo.connect();
        
        // 1. Delete removed contacts from emergency_contacts collection
        for (final phone in deletedPhones) {
          debugPrint('[SafetyProvider] Deleting contact with phone=$phone from MongoDB');
          await mongo.deleteContactByPhone(email, phone);
        }
        
        // 2. Update user profile trusted list
        await mongo.updateUser(email, {
          'profile.trustedContacts': validContacts.map((c) => c.phone).toList(),
        });
        
        // 3. Upsert remaining contacts in emergency_contacts collection
        for (var c in validContacts) {
          await mongo.addContact(email, {
            'name': c.name,
            'phone': c.phone,
            'relationship': 'Guardian',
            'user_email': email,
          });
        }
      } catch (e) {
        debugPrint('[SafetyProvider] Failed to sync contacts to cloud: $e');
      }
    }
    
    notifyListeners();
  }

  Future<void> triggerSOSFlow() async {
    if (_sosProvider == null) return;
    
    // Build message with location if available, or generic message
    final String msg;
    if (latitude != null && longitude != null) {
      msg = '🚨 EMERGENCY SOS 🚨\nI need help! My live location:\nhttps://www.google.com/maps?q=$latitude,$longitude\n(Sent via SHEild AI Safety App)';
    } else {
      msg = '🚨 EMERGENCY SOS 🚨\nI need help! Please call me immediately!\n(Sent via SHEild AI Safety App)';
    }
    
    // Extract phone numbers for the SMS service
    final List<String> phoneNumbers = _trustedContacts.map((c) => c.phone).toList();
    
    // SOS fires unconditionally - SOSProvider handles location internally
    await _sosProvider!.triggerSOS(
      customContacts: phoneNumbers.isNotEmpty ? phoneNumbers : null,
      customMessage: msg,
    );
    _alerts.insert(0, AlertItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'SOS',
      title: 'SOS Activated',
      body: 'Emergency SOS sent to guardians.',
      timestamp: DateTime.now(),
      riskLevel: riskLabel,
    ));
    notifyListeners();
  }

  Future<void> confirmSafe() async {
    if (_sosProvider != null) {
      await _sosProvider!.cancelSOS();
      final msg = 'SAFE: I am safe now. Thank you for your support. My location: $_readableAddress';
      
      final List<String> phoneNumbers = _trustedContacts.map((c) => c.phone).toList();
      SMSService().sendBulkSMS(phoneNumbers: phoneNumbers, message: msg);
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

  void clearAlerts() {
    _alerts.clear();
    notifyListeners();
  }

  void removeAlert(String id) {
    _alerts.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  void refreshSOSState() { notifyListeners(); }
  
  Future<bool> submitCommunityReport(String type, String desc, int severity) async {
    try {
      if (latitude == null || longitude == null) return false;
      
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
    _sosProvider?.removeListener(_onSOSStateChanged);
    _durationTimer?.cancel();
    super.dispose();
  }
}