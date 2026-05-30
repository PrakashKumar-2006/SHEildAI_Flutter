import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import '../utils/shake_config.dart';

class ShakeDetectionService {
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final _shakeController = StreamController<void>.broadcast();
  
  int _shakeCount = 0;
  DateTime? _lastShakeTime;
  DateTime? _windowStartTime;

  Stream<void> get onShake => _shakeController.stream;

  void startListening() {
    _subscription?.cancel();
    _shakeCount = 0;
    
    _subscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      final double acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      if (acceleration > ShakeConfig.shakeThreshold) {
        final now = DateTime.now();
        
        // Ensure minimum interval between shakes to avoid counting one movement twice
        if (_lastShakeTime != null && 
            now.difference(_lastShakeTime!).inMilliseconds < ShakeConfig.minShakeIntervalMs) {
          return;
        }

        // Check if we are within the detection window
        if (_windowStartTime == null || 
            now.difference(_windowStartTime!).inMilliseconds > ShakeConfig.shakeWindowMs) {
          _windowStartTime = now;
          _shakeCount = 1;
        } else {
          _shakeCount++;
        }

        _lastShakeTime = now;

        if (_shakeCount >= ShakeConfig.minShakeCount) {
          _shakeController.add(null);
          _shakeCount = 0; // Reset after trigger
          _windowStartTime = null;
        }
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _shakeCount = 0;
    _windowStartTime = null;
  }

  void dispose() {
    stopListening();
    _shakeController.close();
  }
}
