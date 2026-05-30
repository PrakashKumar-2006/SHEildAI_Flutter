import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/wearable_notification_channels.dart';
import '../utils/wearable_action_handler.dart';

class WearableNotificationService {
  static final WearableNotificationService _instance = WearableNotificationService._internal();
  factory WearableNotificationService() => _instance;

  WearableNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      for (final channel in WearableNotificationChannels.allChannels) {
        await androidPlugin.createNotificationChannel(channel);
      }
    }
  }

  Future<void> showWearableSOSNotification({
    required String message,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      WearableNotificationChannels.emergencyChannel.id,
      WearableNotificationChannels.emergencyChannel.name,
      channelDescription: WearableNotificationChannels.emergencyChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      vibrationPattern: WearableNotificationChannels.sosVibrationPattern,
      category: AndroidNotificationCategory.alarm,
      actions: [
        const AndroidNotificationAction(
          WearableActionHandler.actionCancelSos,
          'CANCEL SOS',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          WearableActionHandler.actionCallGuardian,
          'CALL GUARDIAN',
          showsUserInterface: true,
        ),
      ],
    );

    await _notificationsPlugin.show(
      1001,
      '🆘 SOS ACTIVE',
      message,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showWearableRiskAlert({
    required String zoneName,
    required String message,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      WearableNotificationChannels.riskChannel.id,
      WearableNotificationChannels.riskChannel.name,
      channelDescription: WearableNotificationChannels.riskChannel.description,
      importance: Importance.max,
      priority: Priority.high,
      vibrationPattern: WearableNotificationChannels.riskVibrationPattern,
      category: AndroidNotificationCategory.alarm,
      actions: [
        const AndroidNotificationAction(
          WearableActionHandler.actionViewAlert,
          'VIEW ALERT',
          showsUserInterface: true,
        ),
      ],
    );

    await _notificationsPlugin.show(
      1002,
      '⚠️ RISK ALERT: $zoneName',
      message,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showWearableCommunityAlert({
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      WearableNotificationChannels.communityChannel.id,
      WearableNotificationChannels.communityChannel.name,
      channelDescription: WearableNotificationChannels.communityChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      vibrationPattern: WearableNotificationChannels.communityVibrationPattern,
      actions: [
        const AndroidNotificationAction(
          WearableActionHandler.actionOpenApp,
          'OPEN APP',
          showsUserInterface: true,
        ),
      ],
    );

    await _notificationsPlugin.show(
      1003,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelSOS() async {
    await _notificationsPlugin.cancel(1001);
  }

  Future<void> cancelRisk() async {
    await _notificationsPlugin.cancel(1002);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancel(1001);
    await _notificationsPlugin.cancel(1002);
    await _notificationsPlugin.cancel(1003);
  }
}
