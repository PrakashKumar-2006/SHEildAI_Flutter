import 'package:flutter/material.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/constants/app_constants.dart';

class WearableSettingsProvider with ChangeNotifier {
  final StorageService _storage = StorageService();
  bool _isSmartwatchEnabled = true;

  bool get isSmartwatchEnabled => _isSmartwatchEnabled;

  WearableSettingsProvider() {
    _loadSettings();
  }

  void _loadSettings() {
    _isSmartwatchEnabled = _storage.getBool(AppConstants.keySmartwatchAlertsEnabled) ?? true;
    notifyListeners();
  }

  Future<void> toggleSmartwatchAlerts(bool enabled) async {
    _isSmartwatchEnabled = enabled;
    await _storage.setBool(AppConstants.keySmartwatchAlertsEnabled, enabled);
    notifyListeners();
  }
}
