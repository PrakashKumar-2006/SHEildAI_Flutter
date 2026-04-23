import 'package:flutter/foundation.dart';
import '../../../../core/services/location_service.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../domain/models/location_model.dart';

class LocationProvider extends ChangeNotifier {
  final LocationRepositoryImpl _locationRepository;
  final LocationService _locationService;

  LocationModel? _currentLocation;
  bool _isLoading = false;
  bool _isTracking = false;
  String? _errorMessage;

  LocationProvider({
    required LocationRepositoryImpl locationRepository,
    required LocationService locationService,
  })  : _locationRepository = locationRepository,
        _locationService = locationService;

  LocationModel? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;
  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage;

  Future<void> getCurrentLocation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _locationRepository.getCurrentLocation();
      result.fold(
        (failure) {
          _errorMessage = failure.toString();
          _isLoading = false;
          notifyListeners();
        },
        (location) {
          _currentLocation = location;
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

  Future<void> startTracking({bool background = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _locationRepository.startLocationUpdates(background: background);
      result.fold(
        (failure) {
          _errorMessage = failure.toString();
          _isLoading = false;
          notifyListeners();
        },
        (_) {
          _isTracking = true;
          _isLoading = false;

          // Listen to location stream
          _locationRepository.getLocationStream()?.listen((location) {
            _currentLocation = location;
            notifyListeners();
          });

          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> stopTracking() async {
    try {
      await _locationRepository.stopLocationUpdates();
      _isTracking = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> hasPermission() async {
    return await _locationService.hasPermission();
  }

  Future<bool> requestPermission() async {
    return await _locationService.requestPermission();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationRepository.dispose();
    super.dispose();
  }
}
