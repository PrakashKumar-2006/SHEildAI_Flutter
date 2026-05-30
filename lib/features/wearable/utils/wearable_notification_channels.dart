import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';

class WearableNotificationChannels {
  // 1. EMERGENCY CHANNEL - Maximum priority
  static const AndroidNotificationChannel emergencyChannel = AndroidNotificationChannel(
    'wear_emergency_channel',
    '🚨 Emergency Alerts',
    description: 'High-priority SOS and emergency alerts',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  // 2. RISK ALERT CHANNEL - High priority
  static const AndroidNotificationChannel riskChannel = AndroidNotificationChannel(
    'wear_risk_channel',
    '⚠️ Zone Warnings',
    description: 'Alerts for entering risky areas',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  // 3. COMMUNITY CHANNEL - High priority
  static const AndroidNotificationChannel communityChannel = AndroidNotificationChannel(
    'wear_community_channel',
    '🤝 Community Sentinel',
    description: 'Updates from volunteers and nearby help',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  // 4. FEED CHANNEL - Normal priority
  static const AndroidNotificationChannel feedChannel = AndroidNotificationChannel(
    'wear_feed_channel',
    '📱 Safety Feed',
    description: 'General safety awareness and updates',
    importance: Importance.defaultImportance,
    playSound: false,
    enableVibration: false,
  );

  // Custom Vibration Patterns
  static final Int64List sosVibrationPattern = Int64List.fromList([0, 1000, 500, 1000, 500, 1000]);
  static final Int64List riskVibrationPattern = Int64List.fromList([0, 500, 200, 500]);
  static final Int64List communityVibrationPattern = Int64List.fromList([0, 200, 100, 200]);

  static List<AndroidNotificationChannel> get allChannels => [
        emergencyChannel,
        riskChannel,
        communityChannel,
        feedChannel,
      ];
}
