import 'package:flutter/foundation.dart';
import '../../../../core/services/location_service.dart';
import '../../data/repositories/sos_repository_impl.dart';
import '../../domain/models/sos_model.dart';
import '../../../location/presentation/providers/location_provider.dart';

class SOSProvider extends ChangeNotifier {
  final SOSRepositoryImpl _sosRepository;
  final LocationService _locationService;
  final LocationProvider _locationProvider;

  SOSModel? _activeSOS;
  bool _isLoading = false;
  String? _errorMessage;
  String _sessionDuration = '00:00';
  String _currentLocation = 'Current Location';

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
          // Start background location tracking during SOS
          _locationProvider.startTracking(background: true);
          notifyListeners();
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

  void _startDurationTimer() {
    final startTime = DateTime.now();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_activeSOS == null) return false;
      
      final duration = DateTime.now().difference(startTime);
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      _sessionDuration = '$minutes:$seconds';
      notifyListeners();
      return true;
    });
  }
}
