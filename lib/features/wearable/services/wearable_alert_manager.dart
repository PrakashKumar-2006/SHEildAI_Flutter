import 'wearable_notification_service.dart';
import '../providers/wearable_settings_provider.dart';

class WearableAlertManager {
  static final WearableAlertManager _instance = WearableAlertManager._internal();
  factory WearableAlertManager() => _instance;

  WearableAlertManager._internal();

  final WearableNotificationService _notificationService = WearableNotificationService();
  WearableSettingsProvider? _settingsProvider;

  void initialize(WearableSettingsProvider settings) {
    _settingsProvider = settings;
    _notificationService.initialize();
  }

  void onSosTriggered(String message) {
    if (_settingsProvider?.isSmartwatchEnabled ?? true) {
      _notificationService.showWearableSOSNotification(message: message);
    }
  }

  void onRiskZoneEntry(String zoneName, String message) {
    if (_settingsProvider?.isSmartwatchEnabled ?? true) {
      _notificationService.showWearableRiskAlert(
        zoneName: zoneName,
        message: message,
      );
    }
  }

  void onCommunityAlert(String title, String message) {
    if (_settingsProvider?.isSmartwatchEnabled ?? true) {
      _notificationService.showWearableCommunityAlert(
        title: title,
        body: message,
      );
    }
  }

  void cancelSOS() {
    _notificationService.cancelSOS();
  }

  void cancelRisk() {
    _notificationService.cancelRisk();
  }

  void cancelAll() {
    _notificationService.cancelAll();
  }
}
