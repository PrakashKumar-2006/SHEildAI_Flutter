import 'package:flutter/foundation.dart';
import '../../../../core/services/location_service.dart';
import '../../data/repositories/sos_repository_impl.dart';
import '../../domain/models/sos_model.dart';

class SOSProvider extends ChangeNotifier {
  final SOSRepositoryImpl _sosRepository;
  final LocationService _locationService;

  SOSModel? _activeSOS;
  bool _isLoading = false;
  String? _errorMessage;

  SOSProvider({
    required SOSRepositoryImpl sosRepository,
    required LocationService locationService,
  })  : _sosRepository = sosRepository,
        _locationService = locationService;

  SOSModel? get activeSOS => _activeSOS;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSOSActive => _activeSOS != null;

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
