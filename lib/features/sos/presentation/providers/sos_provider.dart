import 'package:flutter/foundation.dart';
import '../../../../core/services/location_service.dart';
import '../../data/repositories/sos_repository_impl.dart';
import '../../domain/models/sos_model.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../../core/services/sms_service.dart';
import '../../../../core/services/video_recording_service.dart';
import '../../../../features/contacts/data/repositories/contact_repository_impl.dart';

class SOSProvider extends ChangeNotifier {
  final SOSRepositoryImpl _sosRepository;
  final LocationService _locationService;
  final LocationProvider _locationProvider;
  final ContactRepositoryImpl _contactRepository;

  SOSModel? _activeSOS;
  bool _isLoading = false;
  String? _errorMessage;
  final String _sessionDuration = '00:00';
  final String _currentLocation = 'Current Location';

   SOSProvider({
    required SOSRepositoryImpl sosRepository,
    required LocationService locationService,
    required LocationProvider locationProvider,
    required ContactRepositoryImpl contactRepository,
  })  : _sosRepository = sosRepository,
        _locationService = locationService,
        _locationProvider = locationProvider,
        _contactRepository = contactRepository;

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
      // Get location — use cached if available, otherwise fetch fresh
      double lat;
      double lon;

      final cachedLoc = _locationProvider.currentLocation;
      if (cachedLoc != null) {
        lat = cachedLoc.latitude;
        lon = cachedLoc.longitude;
        debugPrint('[SOS] Using cached location: $lat, $lon');
      } else {
        debugPrint('[SOS] No cached location, fetching fresh...');
        try {
          final pos = await _locationService.getCurrentPosition();
          lat = pos.latitude;
          lon = pos.longitude;
        } catch (e) {
          // Last resort: use 0,0 so SOS still fires
          lat = 0.0;
          lon = 0.0;
          debugPrint('[SOS] Could not get location, using 0,0: $e');
        }
      }

      // Get emergency contacts from database
      List<String> contacts = customContacts ?? [];
      if (contacts.isEmpty) {
        final contactsResult = await _contactRepository.getContacts();
        contactsResult.fold(
          (failure) {
            debugPrint('[SOS] Contact DB error, using emergency numbers: $failure');
            contacts = ['112']; // India emergency
          },
          (dbContacts) {
            if (dbContacts.isNotEmpty) {
              contacts = dbContacts.map((c) => c.phone).toList();
              debugPrint('[SOS] Loaded ${contacts.length} guardian contacts: ${contacts.join(", ")}');
            } else {
              debugPrint('[SOS] No guardians saved, using emergency number');
              contacts = ['112'];
            }
          },
        );
      }

      // Trigger SOS record
      final result = await _sosRepository.triggerSOS(
        latitude: lat,
        longitude: lon,
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

          // Build precise Google Maps link
          final locationUrl = lat != 0.0
              ? 'https://www.google.com/maps?q=$lat,$lon'
              : 'Location unavailable';
          final message = customMessage ??
              '🚨 EMERGENCY SOS 🚨\nI need help! My live location:\n$locationUrl\n(Sent via SHEild AI Safety App)';

          debugPrint('[SOS] Sending SMS to: ${contacts.join(", ")}');
          debugPrint('[SOS] Message: $message');

          // Send SMS in background - do NOT await to avoid blocking UI
          SMSService().sendBulkSMS(
            phoneNumbers: contacts,
            message: message,
          ).then((_) {
            debugPrint('[SOS] SMS dispatch completed.');
          }).catchError((e) {
            debugPrint('[SOS] SMS error: $e');
          });

          // Start background video recording
          VideoRecordingService().startRecording().catchError((e) {
            debugPrint('[SOS] Video recording failed: $e');
          });
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      debugPrint('[SOS] Error: $e');
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
      await _locationProvider.stopTracking();
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
