import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(initializationSettings);
    _initialized = true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationDetails? notificationDetails,
  }) async {
    await initialize();

    final NotificationDetails details = notificationDetails ??
        NotificationDetails(
          android: AndroidNotificationDetails(
            'sheild_ai_channel',
            'SHEild AI Notifications',
            channelDescription: 'Emergency and safety notifications',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            icon: '@mipmap/ic_launcher',
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showSOSNotification({
    required String message,
    String? location,
  }) async {
    await showNotification(
      id: 1,
      title: '🚨 SOS ACTIVATED',
      body: message,
      payload: 'sos',
    );
  }

  Future<void> showLocationUpdateNotification({
    required String message,
  }) async {
    await showNotification(
      id: 2,
      title: '📍 Location Updated',
      body: message,
      payload: 'location',
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> showZoneEntryAlert({
    required String zoneName,
    required String message,
  }) async {
    await showNotification(
      id: 200,
      title: '🚨 ZONE ENTRY ALERT: $zoneName',
      body: message,
      payload: 'zone_alert',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'zone_alert_channel',
          'Zone Alerts',
          channelDescription: 'High-priority alerts for risky zones',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          enableVibration: true,
          playSound: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          ongoing: true,
          autoCancel: false,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.critical,
        ),
      ),
    );
  }

  Future<void> showCommunitySOSNotification({
    required String name,
    required double distanceMeters,
  }) async {
    final distanceKm = (distanceMeters / 1000).toStringAsFixed(1);
    await showNotification(
      id: 100,
      title: '🚨 EMERGENCY NEARBY: $name',
      body: 'Someone needs help within $distanceKm km of your location!',
      payload: 'community_sos',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'emergency_channel',
          'Emergency Alerts',
          channelDescription: 'High-priority alerts for nearby emergencies',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          enableVibration: true,
          playSound: true,
          category: AndroidNotificationCategory.event,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
    );
  }


  Future<void> cancelSOSNotifications() async {
    await cancelNotification(1);
  }
}
