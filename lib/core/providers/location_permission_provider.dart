import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

enum PermissionStatus { checking, granted, denied, blocked, unavailable }
enum GpsStatus { checking, enabled, disabled }

class LocationPermissionProvider extends ChangeNotifier {
  final LocationService _locationService;
  
  PermissionStatus _permissionStatus = PermissionStatus.checking;
  GpsStatus _gpsStatus = GpsStatus.checking;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<ServiceStatus>? _gpsStatusSubscription;

  LocationPermissionProvider(this._locationService) {
    _initialize();
  }

  PermissionStatus get permissionStatus => _permissionStatus;
  GpsStatus get gpsStatus => _gpsStatus;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  bool get canUseApp => 
      _permissionStatus == PermissionStatus.granted && 
      _gpsStatus == GpsStatus.enabled;
  
  bool get isPermissionDenied => 
      _permissionStatus == PermissionStatus.denied ||
      _permissionStatus == PermissionStatus.blocked;
      
  bool get isGpsDisabled => _gpsStatus == GpsStatus.disabled;

  void _initialize() {
    _checkPermissionAndGPS();
    _startGpsStatusMonitoring();
  }

  void _startGpsStatusMonitoring() {
    _gpsStatusSubscription = Geolocator.getServiceStatusStream().listen(
      (ServiceStatus status) {
        if (status == ServiceStatus.enabled) {
          _gpsStatus = GpsStatus.enabled;
        } else {
          _gpsStatus = GpsStatus.disabled;
        }
        notifyListeners();
      },
    );
  }

  Future<void> _checkPermissionAndGPS() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check GPS status
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      _gpsStatus = serviceEnabled ? GpsStatus.enabled : GpsStatus.disabled;

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          _permissionStatus = PermissionStatus.granted;
          break;
        case LocationPermission.denied:
          _permissionStatus = PermissionStatus.denied;
          break;
        case LocationPermission.deniedForever:
          _permissionStatus = PermissionStatus.blocked;
          break;
        case LocationPermission.unableToDetermine:
          _permissionStatus = PermissionStatus.unavailable;
          break;
      }

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to check location status: $e';
      _permissionStatus = PermissionStatus.unavailable;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestLocationPermission() async {
    _isLoading = true;
    notifyListeners();

    try {
      // First check if GPS is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _gpsStatus = GpsStatus.disabled;
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _gpsStatus = GpsStatus.enabled;

      // Request permission
      LocationPermission permission = await Geolocator.requestPermission();
      
      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          _permissionStatus = PermissionStatus.granted;
          _startLocationUpdates();
          break;
        case LocationPermission.denied:
          _permissionStatus = PermissionStatus.denied;
          break;
        case LocationPermission.deniedForever:
          _permissionStatus = PermissionStatus.blocked;
          break;
        case LocationPermission.unableToDetermine:
          _permissionStatus = PermissionStatus.unavailable;
          break;
      }

      _errorMessage = null;
      _isLoading = false;
      notifyListeners();
      
      return _permissionStatus == PermissionStatus.granted;
    } catch (e) {
      _errorMessage = 'Failed to request permission: $e';
      _isLoading = false;
      _permissionStatus = PermissionStatus.unavailable;
      notifyListeners();
      return false;
    }
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  void _startLocationUpdates() {
    _locationService.startLocationUpdates(background: false);
  }

  Future<void> refreshStatus() async {
    await _checkPermissionAndGPS();
  }

  @override
  void dispose() {
    _gpsStatusSubscription?.cancel();
    super.dispose();
  }
}
