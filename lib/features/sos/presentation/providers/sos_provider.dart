import 'package:flutter/foundation.dart';
import '../../../../core/services/location_service.dart';
import '../../data/repositories/sos_repository_impl.dart';
import '../../domain/models/sos_model.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../../core/services/sms_service.dart';
import '../../../../core/services/video_recording_service.dart';

class SOSProvider extends ChangeNotifier {
  final SOSRepositoryImpl _sosRepository;
  final LocationService _locationService;
  final LocationProvider _locationProvider;

  SOSModel? _activeSOS;
  bool _isLoading = false;
  String? _errorMessage;
  final String _sessionDuration = '00:00';
  final String _currentLocation = 'Current Location';

  SOSProvider({
    required SOSRepositoryImpl sosRepository,
    required LocationService locationService,
    required LocationProvider locationProvider,
  })  : _sosRepository = sosRepository,
        _locationService = locationService,
        _locationProvider = locationProvider;

  SOSModel? get activeSOS => _activeSOS;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSOSActive => _activeSOS != null;
  String get sessionDuration => _sessionDuration;
  String get currentLocation => _currentLocation;

  Future<void> triggerSOS({
    List<String>? customContacts,
    String? customMessage,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Get current location
      final position = await _locationService.getCurrentPosition();

      // Get emergency contacts (default if none provided)
      final contacts = customContacts ?? ['100', '1091'];

      // Trigger SOS
      final result = await _sosRepository.triggerSOS(
        latitude: position.latitude,
        longitude: position.longitude,
        contacts: contacts,
        message: customMessage,
      );

      result.fold(
        (failure) {
          _errorMessage = failure.toString();
          _isLoading = false;
          notifyListeners();
        },
        (sos) {
          _activeSOS = sos;
          _isLoading = false;
          _locationProvider.startTracking(background: true);
          notifyListeners();

          // Send SMS to contacts
          final message = customMessage ?? 'EMERGENCY: I need help! My location: https://maps.google.com/?q=${position.latitude},${position.longitude}';
          debugPrint('[SOS] Triggering bulk SMS to: ${contacts.join(', ')}');
          
          SMSService().sendBulkSMS(
            phoneNumbers: contacts,
            message: message,
          ).then((_) {
            debugPrint('[SOS] Bulk SMS sending process completed.');
          }).catchError((e) {
            debugPrint('[SOS] Error in bulk SMS sending: $e');
          });

          // Start background video recording
          VideoRecordingService().startRecording().catchError((e) {
            debugPrint('Failed to start video recording: $e');
          });
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelSOS() async {
    if (_activeSOS == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _sosRepository.cancelSOS(_activeSOS!.id);
      _activeSOS = null;
      _isLoading = false;
      // Stop background location tracking
      await _locationProvider.stopTracking();
      // Stop video recording if active
      if (VideoRecordingService().isRecording) {
        await VideoRecordingService().stopRecording();
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkSOSStatus() async {
    final result = await _sosRepository.isSOSActive();
    result.fold(
      (failure) => null,
      (isActive) {
        if (!isActive && _activeSOS != null) {
          _activeSOS = null;
          notifyListeners();
        }
      },
    );
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
