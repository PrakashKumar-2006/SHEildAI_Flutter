import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class SMSService {
  static final SMSService _instance = SMSService._internal();
  factory SMSService() => _instance;

  SMSService._internal();

  final StreamController<Map<String, dynamic>> _smsStatusController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get smsStatusStream => _smsStatusController.stream;

  Future<void> sendSMS({
    required String phoneNumber,
    required String message,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 5),
  }) async {
    int attempt = 0;
    bool success = false;

    while (attempt < maxRetries && !success) {
      attempt++;
      
      try {
        final uri = Uri.parse('sms:$phoneNumber?body=${Uri.encodeComponent(message)}');
        
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(uri);
          if (launched) {
            success = true;
            _smsStatusController.add({
              'status': 'sent',
              'phoneNumber': phoneNumber,
              'attempt': attempt,
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
        }
        
        if (!success && attempt < maxRetries) {
          await Future.delayed(retryDelay);
        } else if (!success) {
          _smsStatusController.addError({
            'status': 'failed',
            'phoneNumber': phoneNumber,
            'attempt': attempt,
            'error': 'Failed to launch SMS',
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        } else {
          _smsStatusController.addError({
            'status': 'failed',
            'phoneNumber': phoneNumber,
            'attempt': attempt,
            'error': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      }
    }
  }

  Future<void> sendBulkSMS({
    required List<String> phoneNumbers,
    required String message,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 5),
  }) async {
    for (final phoneNumber in phoneNumbers) {
      await sendSMS(
        phoneNumber: phoneNumber,
        message: message,
        maxRetries: maxRetries,
        retryDelay: retryDelay,
      );
    }
  }

  void dispose() {
    _smsStatusController.close();
  }
}
