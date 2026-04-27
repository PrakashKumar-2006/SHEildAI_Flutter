import 'package:flutter/services.dart';

class SOSService {
  static const MethodChannel _channel = MethodChannel('sos_channel');

  Future<void> startSOS() async {
    try {
      await _channel.invokeMethod('startSOS');
    } on PlatformException catch (e) {
      // Platform communication only. Errors can be handled by the caller.
      throw Exception("Failed to start SOS: '${e.message}'.");
    }
  }

  Future<void> stopSOS() async {
    try {
      await _channel.invokeMethod('stopSOS');
    } on PlatformException catch (e) {
      // Platform communication only. Errors can be handled by the caller.
      throw Exception("Failed to stop SOS: '${e.message}'.");
    }
  }
}
