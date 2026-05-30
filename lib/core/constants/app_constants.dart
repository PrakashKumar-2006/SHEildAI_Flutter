import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // App Info
  static const String appName = 'SHEild AI';
  static const String appVersion = '1.0.0';

  // Emergency Numbers
  static const String emergencyPolice = '100';
  static const String emergencyWomenHelpline = '1091';
  static const String emergencyAmbulance = '102';
  static const String emergencyFire = '101';

  // SOS Settings
  static const int sosCooldownSeconds = 30;
  static String get mongoUri => dotenv.env['MONGO_URI'] ?? '';
  static const int sosAutoCancelMinutes = 5;
  static const int locationUpdateIntervalSeconds = 5;

  // Storage Keys
  static const String keyUserId = 'user_id';
  static const String keyEmergencyContacts = 'emergency_contacts';
  static const String keyLocationHistory = 'location_history';
  static const String keySosHistory = 'sos_history';
  static const String keyVoiceTriggerEnabled = 'voice_trigger_enabled';
  static const String keyShakeTriggerEnabled = 'shake_trigger_enabled';
  static const String keySmartwatchAlertsEnabled = 'smartwatch_alerts_enabled';
  static const String keyLastSosTime = 'last_sos_time';
  static const String keyUserName = 'user_name';
  static const String keyUserPhone = 'user_phone';
  static const String keyUserEmail = 'user_email';

  /// Persisted login session flag — true after a successful sign-in,
  /// cleared on explicit sign-out. Survives cold restarts so the user
  /// is not forced to re-authenticate on every app launch.
  static const String keyIsLoggedIn = 'is_logged_in';

  // Voice Triggers
  static const List<String> voiceTriggers = [
    'help',
    'sos',
    'emergency',
    'save me',
    'danger',
  ];

  // API Endpoints (Backend-ready)
  static const String baseUrl = 'https://api.sheildai.com/v1';
  static const String endpointSos = '/sos';
  static const String endpointLocation = '/location';
  static const String endpointContacts = '/contacts';

  // Map Settings
  static const double defaultZoom = 15.0;
  static const double maxZoom = 18.0;
  static const double minZoom = 5.0;
}
