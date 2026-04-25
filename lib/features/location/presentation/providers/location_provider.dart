import 'dart:async';
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
  StreamSubscription? _streamSubscription;

  LocationProvider({
    required LocationRepositoryImpl locationRepository,
    required LocationService locationService,
  })  : _locationRepository = locationRepository,
        _locationService = locationService {
    // Auto-start on creation
    _bootLocation();
  }

  LocationModel? get currentLocation => _currentLocation;
  bool get isLoading => _isLoading;
  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage;

  /// Called automatically at app boot.
  /// 1. Immediately tries to get a fast position (last known or GPS race)
  /// 2. Starts a continuous stream for live updates
  Future<void> _bootLocation() async {
    debugPrint('[LocationProvider] Booting location...');
    _isLoading = true;
    notifyListeners();

    // Step 1: get a quick fix
    try {
      final perm = await _locationService.requestPermission();
      if (!perm) {
        _errorMessage = 'Location permission denied. Please grant it in settings.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Fire off immediate fix (doesn't block stream start)
      _locationService.getCurrentPosition().then((position) {
        _currentLocation = LocationModel(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          timestamp: position.timestamp,
        );
        _isLoading = false;
        debugPrint('[LocationProvider] Got initial fix: ${position.latitude}, ${position.longitude}');
        notifyListeners();
      }).catchError((e) {
        debugPrint('[LocationProvider] Initial fix failed: $e');
        _isLoading = false;
        _errorMessage = 'Could not get GPS fix. Ensure GPS is enabled.';
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[LocationProvider] Permission error: $e');
    }

    // Step 2: start continuous stream for live updates
    _startStream();
  }

  void _startStream() {
    if (_isTracking) return;
    _locationService.startLocationUpdates(background: false);
    _isTracking = true;

    _streamSubscription?.cancel();
    _streamSubscription = _locationService.positionStream.listen(
      (position) {
        _currentLocation = LocationModel(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          timestamp: position.timestamp,
        );
        _isLoading = false;
        _errorMessage = null;
        debugPrint('[LocationProvider] Stream update: ${position.latitude}, ${position.longitude}');
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[LocationProvider] Stream error: $e');
        _errorMessage = e.toString();
        notifyListeners();
      },
    );
  }

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
    if (_isTracking && !background) return;

    _locationService.stopLocationUpdates();
    _streamSubscription?.cancel();
    _isTracking = false;

    _locationService.startLocationUpdates(background: background);
    _isTracking = true;

    _streamSubscription = _locationService.positionStream.listen(
      (position) {
        _currentLocation = LocationModel(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          timestamp: position.timestamp,
        );
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[LocationProvider] Tracking error: $e');
      },
    );
    notifyListeners();
  }

  Future<void> stopTracking() async {
    _locationService.stopLocationUpdates();
    _streamSubscription?.cancel();
    _isTracking = false;
    notifyListeners();
  }

  Future<bool> hasPermission() async =>
      await _locationService.hasPermission();

  Future<bool> requestPermission() async =>
      await _locationService.requestPermission();

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _locationRepository.dispose();
    super.dispose();
  }
}
