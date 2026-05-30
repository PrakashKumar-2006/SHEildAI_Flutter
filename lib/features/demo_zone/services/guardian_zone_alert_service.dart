import '../../../core/services/sms_service.dart';
import '../utils/demo_zone_config.dart';
import 'package:flutter/foundation.dart';

class GuardianZoneAlertService {
  final SMSService _smsService = SMSService();

  Future<void> sendGuardianAlerts({
    required List<String> guardianPhones,
    required double lat,
    required double lng,
  }) async {
    if (guardianPhones.isEmpty) {
      debugPrint('[DemoZone] No guardians to alert.');
      return;
    }

    final message = DemoZoneConfig.getGuardianMessage(lat, lng);
    debugPrint('[DemoZone] Sending direct alerts to ${guardianPhones.length} guardians: $guardianPhones');
    debugPrint('[DemoZone] Message content: $message');
    
    try {
      await _smsService.sendBulkSMS(
        phoneNumbers: guardianPhones,
        message: message,
      );
      debugPrint('[DemoZone] Guardian alerts dispatched successfully.');
    } catch (e) {
      debugPrint('[DemoZone] ERROR in DemoZone Alert Service: $e');
    }
  }
}
