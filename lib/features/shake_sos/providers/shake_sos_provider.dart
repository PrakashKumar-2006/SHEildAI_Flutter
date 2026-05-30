import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import '../services/shake_detection_service.dart';
import '../services/shake_settings_service.dart';
import '../utils/shake_config.dart';

class ShakeSosProvider extends ChangeNotifier {
  final ShakeDetectionService _detectionService;
  final ShakeSettingsService _settingsService;
  
  bool _isEnabled = false;
  bool _isListening = false;
  DateTime? _lastTriggerTime;

  bool get isEnabled => _isEnabled;
  bool get isListening => _isListening;

  final _onShakeDetectedController = StreamController<void>.broadcast();
  Stream<void> get onShakeDetected => _onShakeDetectedController.stream;

  ShakeSosProvider({
    required ShakeDetectionService detectionService,
    required ShakeSettingsService settingsService,
  }) : _detectionService = detectionService,
       _settingsService = settingsService {
    _init();
  }

  Future<void> _init() async {
    _isEnabled = await _settingsService.isShakeTriggerEnabled();
    if (_isEnabled) {
      startListening();
    }
    notifyListeners();
  }

  void startListening() {
    if (_isListening) return;
    
    _detectionService.startListening();
    _detectionService.onShake.listen((_) => _handleShake());
    _isListening = true;
    notifyListeners();
  }

  void stopListening() {
    _detectionService.stopListening();
    _isListening = false;
    notifyListeners();
  }

  Future<void> toggleEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _settingsService.setShakeTriggerEnabled(enabled);
    
    if (enabled) {
      startListening();
    } else {
      stopListening();
    }
    notifyListeners();
  }

  void _handleShake() async {
    if (!_isEnabled) return;

    // Cooldown check
    final now = DateTime.now();
    if (_lastTriggerTime != null && 
        now.difference(_lastTriggerTime!).inSeconds < ShakeConfig.triggerCooldownSeconds) {
      debugPrint('[ShakeSOS] Shake detected but in cooldown.');
      return;
    }

    _lastTriggerTime = now;
    debugPrint('[ShakeSOS] Rapid shake detected!');

    // Haptic feedback
    if (await Vibration.hasVibrator() == true) {
      Vibration.vibrate(pattern: [0, 200, 100, 200]);
    }

    _onShakeDetectedController.add(null);
  }

  @override
  void dispose() {
    _detectionService.dispose();
    _onShakeDetectedController.close();
    super.dispose();
  }
}
