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
  static const int sosAutoCancelMinutes = 5;
  static const int locationUpdateIntervalSeconds = 10;

  // Storage Keys
  static const String keyUserId = 'user_id';
  static const String keyEmergencyContacts = 'emergency_contacts';
  static const String keyLocationHistory = 'location_history';
  static const String keySosHistory = 'sos_history';
  static const String keyVoiceTriggerEnabled = 'voice_trigger_enabled';
  static const String keyLastSosTime = 'last_sos_time';

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
