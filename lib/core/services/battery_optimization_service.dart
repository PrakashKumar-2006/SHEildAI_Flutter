import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service to handle OEM and Android Doze battery optimization exemptions.
class BatteryOptimizationService {
  static const MethodChannel _channel = MethodChannel('sos_channel');

  /// Requests the OS to exempt this app from battery optimization.
  /// 
  /// This is required for background services (like voice detection) to 
  /// survive when the screen is off or the app is swiped from recents.
  ///
  /// Returns `true` if already exempt, or `false` if the OS dialog was shown
  /// (in which case the result is unknown until the next call).
  static Future<bool> requestExemption() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true; // Not applicable on iOS
    }

    try {
      final isExempt = await _channel.invokeMethod<bool>('requestBatteryOptimizationExemption');
      return isExempt ?? false;
    } on PlatformException catch (e) {
      debugPrint('Failed to request battery exemption: ${e.message}');
      return false;
    }
  }
}
