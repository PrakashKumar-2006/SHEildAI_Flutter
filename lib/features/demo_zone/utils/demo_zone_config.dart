class DemoZoneConfig {
  static const double demoZoneLat = 22.597300;
  static const double demoZoneLng = 75.785328;

  static const double demoZoneRadius = 25.0; // 25 meters
  static const double warningBuffer = 10.0; // 10 meters buffer

  static const double triggerDistance = 35.0; // 25m + 10m = 35m
  static const double resetDistance = 50.0; // Reset alert when distance > 50m

  static const String zoneName = "Demo High-Risk Zone";
  static const String alertTitle = "⚠ High-Risk Zone Ahead";
  static const String alertBody = "You are approaching a monitored area. Please stay alert.";
  
  static String getGuardianMessage(double lat, double lng) {
    return "SHEild AI ALERT: Your loved one is near a high-risk zone.\n\nLocation:\nhttps://maps.google.com/?q=$lat,$lng\n\nPlease stay alert.";
  }
}
