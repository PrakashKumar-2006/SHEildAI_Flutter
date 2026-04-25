import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../constants/app_constants.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  bool _isBackgroundTracking = false;
  Position? _lastKnownPosition;

  Stream<Position> get positionStream => _positionController.stream;
  bool get isBackgroundTracking => _isBackgroundTracking;
  Position? get lastKnownPosition => _lastKnownPosition;

  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[Location] GPS service is disabled!');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  /// Fastest possible location fetch:
  /// 1. Return cached position immediately if fresh (<60s)
  /// 2. Simultaneously fire high-accuracy request
  /// 3. Return first result that arrives
  Future<Position> getCurrentPosition() async {
    final permOk = await requestPermission();
    if (!permOk) throw Exception('Location permission denied');

    final completer = Completer<Position>();
    int finishedCount = 0;
    const totalCandidates = 3;

    void handleSuccess(Position pos, String source) {
      if (!completer.isCompleted) {
        debugPrint('[Location] Got position from $source: ${pos.latitude}, ${pos.longitude}');
        _lastKnownPosition = pos;
        completer.complete(pos);
      }
    }

    void handleFinish() {
      finishedCount++;
      if (finishedCount >= totalCandidates && !completer.isCompleted) {
        completer.completeError(Exception('All location candidates failed'));
      }
    }

    // Candidate 1: Last Known (Fastest)
    _getLastKnownFast().then((pos) => handleSuccess(pos, 'Cache')).catchError((_) => handleFinish());

    // Candidate 2: High Accuracy (Best)
    Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      ),
    ).then((pos) => handleSuccess(pos, 'GPS_High')).catchError((_) => handleFinish());

    // Candidate 3: Medium Accuracy (Fallback)
    Future.delayed(const Duration(milliseconds: 500)).then((_) {
      if (!completer.isCompleted) {
        Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 5),
            forceLocationManager: true,
          ),
        ).then((pos) => handleSuccess(pos, 'GPS_Medium')).catchError((_) => handleFinish());
      } else {
        finishedCount++;
      }
    });

    // Final safety timeout
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        if (_lastKnownPosition != null) return _lastKnownPosition!;
        throw Exception('Location fetch timed out');
      },
    );
  }

  /// Get last known position from OS cache (nearly instant)
  Future<Position> _getLastKnownFast() async {
    // Try internal cache first
    if (_lastKnownPosition != null) {
      final age = DateTime.now().difference(_lastKnownPosition!.timestamp);
      if (age.inMinutes < 2) {
        return _lastKnownPosition!;
      }
    }
    // Try OS last known
    final pos = await Geolocator.getLastKnownPosition();
    if (pos != null) {
      _lastKnownPosition = pos;
      return pos;
    }
    throw Exception('No cached position available');
  }

  void startLocationUpdates({bool background = false}) {
    if (_positionStreamSubscription != null) return;
    _isBackgroundTracking = background;

    late LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // only update on 10m movement - saves battery & gives reliable GPS lock
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: background
            ? const ForegroundNotificationConfig(
                notificationText: 'SHEild AI is protecting you',
                notificationTitle: 'Guardian Mode Active',
                enableWakeLock: true,
              )
            : null,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: background,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    debugPrint('[Location] Starting location stream (background: $background)');

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _lastKnownPosition = position;
        _positionController.add(position);
        debugPrint('[Location] Stream update: ${position.latitude}, ${position.longitude}');
      },
      onError: (error) {
        debugPrint('[Location] Stream error: $error');
        _positionController.addError(error);
      },
    );
  }

  void stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isBackgroundTracking = false;
  }

  Future<double> getDistanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) async {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  Future<String> getAddressFromLatLng(
      double latitude, double longitude) async {
    try {
      final placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final parts = [
          place.name,
          place.subLocality,
          place.locality
        ].where((p) => p != null && p.isNotEmpty).toList();
        return parts.join(', ');
      }
      return '$latitude, $longitude';
    } catch (e) {
      return '$latitude, $longitude';
    }
  }

  void dispose() {
    stopLocationUpdates();
    _positionController.close();
  }
}
