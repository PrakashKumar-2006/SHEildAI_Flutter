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
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();
  bool _isBackgroundTracking = false;

  Stream<Position> get positionStream => _positionController.stream;
  bool get isBackgroundTracking => _isBackgroundTracking;

  Future<bool> hasPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position> getCurrentPosition() async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Location permission denied');
    }

    // Attempt to get last known position first for maximum speed
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        // If last known is fresh (e.g. < 1 min), return it immediately
        final diff = DateTime.now().difference(lastKnown.timestamp);
        if (diff.inMinutes < 1) {
          return lastKnown;
        }
      }
    } catch (e) {
      debugPrint('Error fetching last known location: $e');
    }

    // Otherwise fetch fresh position with high accuracy
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  LocationAccuracy _getAdaptiveAccuracy() {
    // Use lower accuracy when battery is low to save power
    return LocationAccuracy.high;
  }

  void startLocationUpdates({bool background = false}) {
    if (_positionStreamSubscription != null) return;

    _isBackgroundTracking = background;

    final LocationSettings locationSettings = LocationSettings(
      accuracy: _getAdaptiveAccuracy(),
      distanceFilter: background ? 50 : 10,
      timeLimit: Duration(seconds: background ? 30 : AppConstants.locationUpdateIntervalSeconds),
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        _positionController.add(position);
      },
      onError: (error) {
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

  Future<String> getAddressFromLatLng(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return "${place.name}, ${place.subLocality}, ${place.locality}";
      }
      return "$latitude, $longitude";
    } catch (e) {
      return "$latitude, $longitude";
    }
  }

  void dispose() {
    stopLocationUpdates();
    _positionController.close();
  }
}
