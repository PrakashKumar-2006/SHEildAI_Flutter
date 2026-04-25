import 'dart:async';
import 'package:sms_advanced/sms_advanced.dart';
import 'package:flutter/foundation.dart';

class SMSService {
  static final SMSService _instance = SMSService._internal();
  factory SMSService() => _instance;
  SMSService._internal();

  final SmsSender _sender = SmsSender();

  /// Sends a single SMS directly in the background
  Future<bool> sendSMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
      if (cleanPhone.isEmpty) return false;

      debugPrint('[SMS] Attempting to send SMS to $cleanPhone...');
      
      final SmsMessage sms = SmsMessage(cleanPhone, message);
      
      // Listen to delivery status if possible (sms_advanced supports this via state)
      _sender.sendSms(sms);
      
      debugPrint('[SMS] SMS dispatch request successful for $cleanPhone');
      return true;
    } catch (e) {
      debugPrint('[SMS] ERROR sending SMS to $phoneNumber: $e');
      return false;
    }
  }

  /// Sends multiple SMS alerts to a list of contacts with retry logic
  Future<void> sendBulkSMS({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    if (phoneNumbers.isEmpty) {
      debugPrint('[SMS] No phone numbers provided for bulk SMS.');
      return;
    }

    debugPrint('[SMS] Starting bulk SMS to ${phoneNumbers.length} contacts...');

    for (var phone in phoneNumbers) {
      bool sent = false;
      int retries = 0;
      
      while (!sent && retries < 2) { // Try up to 2 times
        sent = await sendSMS(
          phoneNumber: phone,
          message: message,
        );
        
        if (!sent) {
          retries++;
          debugPrint('[SMS] Retry $retries for $phone...');
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      
      // Small delay between different contacts to avoid carrier blocking
      await Future.delayed(const Duration(milliseconds: 800));
    }
    debugPrint('[SMS] Bulk SMS process completed.');
  }
}
