import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class BackgroundMonitorService {
  static final BackgroundMonitorService _instance = BackgroundMonitorService._internal();
  factory BackgroundMonitorService() => _instance;

  BackgroundMonitorService._internal();

  static const String _channelId = 'sheild_ai_background';
  static const String _channelName = 'SHEild AI Background Service';
  static const String _channelDescription = 'Background monitoring for safety features';

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    await _initializeNotifications();
    await _initializeBackgroundService();
    // Ensure service is started on initialization
    await startService();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(initializationSettings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.low,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _initializeBackgroundService() async {
    final service = FlutterBackgroundService();

    service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true, // Changed from false for persistence
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'SHEild AI SafeGuard',
        initialNotificationContent: 'Active Protection Enabled',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true, // Changed from false
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }


  Future<void> startService() async {
    final service = FlutterBackgroundService();
    service.startService();
  }

  Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  Future<bool> isRunning() async {
    final service = FlutterBackgroundService();
    return service.isRunning();
  }

  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
    
    // Load zones for background monitoring
    List<dynamic> backgroundZones = [];
    try {
      final String riskDataString = await rootBundle.loadString('assets/risk_data.json');
      final Map<String, dynamic> riskData = jsonDecode(riskDataString);
      backgroundZones = riskData['zones'];
    } catch (e) {
      debugPrint('[BackgroundService] Error loading zones: $e');
    }

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stop').listen((event) {
      service.stopSelf();
    });

    // Use Geolocator for background location
    final Set<String> triggeredZones = {};
    
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      _checkBackgroundZones(position, backgroundZones, notifications, triggeredZones);
      
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'SHEild AI SafeGuard',
          content: 'Active Protection: Monitoring Location',
        );
      }
    });
  }


  static void _checkBackgroundZones(
    Position position, 
    List<dynamic> zones, 
    FlutterLocalNotificationsPlugin notifications,
    Set<String> triggeredZones,
  ) {
    bool foundAnyZone = false;
    
    for (var zone in zones) {
      final double zoneLat = (zone['lat'] as num).toDouble();
      final double zoneLon = (zone['lon'] as num).toDouble();
      final double baseScore = (zone['base_score'] ?? 0.0).toDouble();
      final String zoneName = zone['name'] ?? 'Unknown Zone';
      final String zoneId = '${zoneLat}_${zoneLon}';
      
      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        zoneLat,
        zoneLon,
      );

      // Trigger if within 500m (zone radius) + 50m (proximity)
      if (distance <= 550 && baseScore > 25) {
        foundAnyZone = true;
        if (!triggeredZones.contains(zoneId)) {
          _showHighPriorityNotification(
            notifications,
            '🚨 ZONE ALERT: $zoneName',
            'You are in a risky area. Stay alert or tap for safety options.',
          );
          triggeredZones.add(zoneId);
        }
      } else {
        // Remove from triggered set if we move away from the zone (hysteresis)
        if (distance > 700) {
          triggeredZones.remove(zoneId);
        }
      }
    }
  }


  static Future<void> _showHighPriorityNotification(
    FlutterLocalNotificationsPlugin notifications,
    String title,
    String content,
  ) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'zone_alert_channel',
      'Zone Alerts',
      channelDescription: 'High-priority alerts for risky zones',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await notifications.show(
      200,
      title,
      content,
      platformChannelSpecifics,
    );
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  Future<void> showMonitoringNotification(String title, String content) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ticker: 'ticker',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.show(
      0,
      title,
      content,
      platformChannelSpecifics,
    );
  }
}
