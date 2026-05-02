import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/services/location_service.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../domain/models/location_model.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/mongo_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationRepositoryImpl _locationRepository;
  final LocationService _locationService;

  LocationModel? _currentLocation;
  bool _isLoading = false;
  bool _isTracking = false;
  String? _errorMessage;
  final StorageService _storageService;
  StreamSubscription? _streamSubscription;
  Timer? _heartbeatTimer;
  DateTime? _lastSyncTime;

  LocationProvider({
    required LocationRepositoryImpl locationRepository,
    required LocationService locationService,
    required StorageService storageService,
  })  : _locationRepository = locationRepository,
        _locationService = locationService,
        _storageService = storageService {
    // Auto-start on creation
    _bootLocation();
    _startHeartbeat();
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

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _syncLocation();
    });
  }

  Future<void> _syncLocation() async {
    if (_currentLocation == null) return;
    
    final now = DateTime.now();
    // Only sync if moved or 1 minute passed since last sync
    if (_lastSyncTime != null && now.difference(_lastSyncTime!).inSeconds < 60) {
       return;
    }

    final phone = _storageService.getString('user_phone') ?? '';
    final email = _storageService.getString('user_email') ?? '';
    final name = _storageService.getString('user_name') ?? 'User';
    final identifier = email.isNotEmpty ? email : phone;

    if (identifier.isEmpty) return;

    debugPrint('[LocationProvider] Heartbeat sync for $identifier');
    
    // 1. Sync with Render Backend (for real-time & cross-platform)
    ApiService.syncUserLocation(identifier, _currentLocation!.latitude, _currentLocation!.longitude, name);
    
    // 2. Sync with MongoDB Atlas (for geospatial queries like finding nearby users)
    MongoService().updateUser(identifier, {
      'name': name,
      'phone': phone,
      'location': {
        'latitude': _currentLocation!.latitude,
        'longitude': _currentLocation!.longitude,
      }
    });

    _lastSyncTime = now;
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
    _heartbeatTimer?.cancel();
    _locationRepository.dispose();
    super.dispose();
  }
}
