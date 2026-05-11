import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionProvider extends ChangeNotifier {
  final Map<Permission, PermissionStatus> _statuses = {};

  Map<Permission, PermissionStatus> get statuses => _statuses;

  PermissionProvider() {
    checkAllPermissions();
  }

  List<Permission> get requiredPermissions => [
    Permission.location,
    Permission.locationAlways,
    Permission.sms,
    Permission.microphone,
    Permission.camera,
    Permission.notification,
    Permission.ignoreBatteryOptimizations,
  ];

  Future<void> checkAllPermissions() async {
    for (var permission in requiredPermissions) {
      _statuses[permission] = await permission.status;
    }
    notifyListeners();
  }

  Future<void> requestPermission(Permission permission) async {
    final status = await permission.request();
    _statuses[permission] = status;
    
    // If location is granted, we might want to check locationAlways too
    if (permission == Permission.location && status.isGranted) {
      _statuses[Permission.locationAlways] = await Permission.locationAlways.status;
    }
    
    notifyListeners();
  }

  bool isGranted(Permission permission) {
    return _statuses[permission]?.isGranted ?? false;
  }

  String getPermissionTitle(Permission permission) {
    if (permission == Permission.location) return 'Location';
    if (permission == Permission.locationAlways) return 'Background Location';
    if (permission == Permission.sms) return 'SMS';
    if (permission == Permission.microphone) return 'Microphone';
    if (permission == Permission.camera) return 'Camera';
    if (permission == Permission.notification) return 'Notifications';
    if (permission == Permission.ignoreBatteryOptimizations) return 'Battery Optimization';
    return permission.toString();
  }

  IconData getPermissionIcon(Permission permission) {
    if (permission == Permission.location) return Icons.location_on_rounded;
    if (permission == Permission.locationAlways) return Icons.my_location_rounded;
    if (permission == Permission.sms) return Icons.textsms_rounded;
    if (permission == Permission.microphone) return Icons.mic_rounded;
    if (permission == Permission.camera) return Icons.videocam_rounded;
    if (permission == Permission.notification) return Icons.notifications_active_rounded;
    if (permission == Permission.ignoreBatteryOptimizations) return Icons.battery_saver_rounded;
    return Icons.security_rounded;
  }
}
