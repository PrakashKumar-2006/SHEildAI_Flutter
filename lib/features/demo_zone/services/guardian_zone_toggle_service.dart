import 'package:shared_preferences/shared_preferences.dart';

class GuardianZoneToggleService {
  static const String _key = 'guardian_zone_alerts_enabled';

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true; // Enabled by default for demo
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}
