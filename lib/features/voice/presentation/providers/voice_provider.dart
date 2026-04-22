import 'package:flutter/foundation.dart';
import '../../../../core/services/voice_service.dart';

class VoiceProvider extends ChangeNotifier {
  final VoiceService _voiceService;

  VoiceProvider({required VoiceService voiceService})
      : _voiceService = voiceService;

  bool _isEnabled = false;
  bool _isListening = false;
  String _lastRecognizedText = '';
  String? _errorMessage;

  bool get isEnabled => _isEnabled;
  bool get isListening => _isListening;
  String get lastRecognizedText => _lastRecognizedText;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    final initialized = await _voiceService.initialize();
    if (initialized) {
      _isEnabled = await _voiceService.hasPermission();
    }
    notifyListeners();
  }

  Future<void> toggleVoiceTrigger(bool enabled) async {
    _isEnabled = enabled;
    notifyListeners();

    if (enabled) {
      await startListening();
    } else {
      await stopListening();
    }
  }

  Future<void> startListening() async {
    if (_isListening) return;

    _isListening = true;
    _errorMessage = null;
    notifyListeners();

    await _voiceService.startListening(
      onResult: (text) {
        _lastRecognizedText = text;
        
        if (_voiceService.isVoiceTrigger(text)) {
          // Voice trigger detected - notify listeners
          notifyListeners();
        }
      },
      onError: (error) {
        _errorMessage = error;
        _isListening = false;
        notifyListeners();
      },
    );
  }

  Future<void> stopListening() async {
    await _voiceService.stopListening();
    _isListening = false;
    notifyListeners();
  }

  bool checkVoiceTrigger(String text) {
    return _voiceService.isVoiceTrigger(text);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }
}
