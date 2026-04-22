import 'package:speech_to_text/speech_to_text.dart';
import '../constants/app_constants.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;

  VoiceService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    _isInitialized = await _speechToText.initialize(
      onError: (error) {
        // Speech recognition error: $error
      },
      onStatus: (status) {
        // Speech recognition status: $status
      },
    );

    return _isInitialized;
  }

  Future<bool> hasPermission() async {
    return _speechToText.hasPermission;
  }

  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onError,
    String localeId = 'en_US',
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!await hasPermission()) {
      onError('Microphone permission not granted');
      return;
    }

    await _speechToText.listen(
      onResult: (result) {
        final recognizedWords = result.recognizedWords.toLowerCase();
        onResult(recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        cancelOnError: false,
        partialResults: true,
        onDevice: false,
      ),
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 30),
      localeId: localeId,
    );

    _isListening = true;
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    _isListening = false;
  }

  Future<void> cancelListening() async {
    await _speechToText.cancel();
    _isListening = false;
  }

  bool isVoiceTrigger(String text) {
    final lowerText = text.toLowerCase();
    return AppConstants.voiceTriggers.any((trigger) =>
        lowerText.contains(trigger.toLowerCase()));
  }

  void dispose() {
    _speechToText.cancel();
  }
}
