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
      debugPrint('[SMS] Sending direct SMS to $phoneNumber...');
      
      final SmsMessage sms = SmsMessage(phoneNumber, message);
      
      // sms_advanced doesn't return a Future for sendSms, it's fire and forget
      // or we can listen to state changes if needed.
      _sender.sendSms(sms);
      
      debugPrint('[SMS] SMS sent request triggered.');
      return true;
    } catch (e) {
      debugPrint('[SMS] Error sending direct SMS: $e');
      return false;
    }
  }

  /// Sends multiple SMS alerts to a list of contacts
  Future<void> sendBulkSMS({
    required List<String> phoneNumbers,
    required String message,
    bool direct = true,
  }) async {
    if (phoneNumbers.isEmpty) return;

    for (var phone in phoneNumbers) {
      if (phone.trim().isEmpty) continue;
      await sendSMS(
        phoneNumber: phone.trim(),
        message: message,
      );
      // Small delay to prevent carrier rate limiting
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }
}
