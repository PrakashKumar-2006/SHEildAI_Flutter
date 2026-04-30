import 'package:flutter/foundation.dart';
import '../../../../core/services/sos_platform_service.dart';

class VoiceProvider extends ChangeNotifier {
  bool _isEnabled = false;
  final String _lastRecognizedText = '';
  String? _errorMessage;

  bool get isEnabled => _isEnabled;
  bool get isListening => _isEnabled; // Native service manages listening state automatically
  String get lastRecognizedText => _lastRecognizedText;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    _isEnabled = await SOSPlatformService.isVoiceDetectionActive();
    notifyListeners();
  }

  Future<void> toggleVoiceTrigger(bool enabled) async {
    _isEnabled = enabled;
    notifyListeners();

    if (enabled) {
      await SOSPlatformService.enableVoiceDetection();
      // Ensure state is synced
      _isEnabled = await SOSPlatformService.isVoiceDetectionActive();
    } else {
      await SOSPlatformService.disableVoiceDetection();
      _isEnabled = await SOSPlatformService.isVoiceDetectionActive();
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
