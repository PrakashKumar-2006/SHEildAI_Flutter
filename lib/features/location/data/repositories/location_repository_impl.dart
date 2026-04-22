import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/location_service.dart';
import '../../domain/models/location_model.dart';
import '../../domain/repositories/location_repository.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationService _locationService;
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<LocationModel> _locationController =
      StreamController<LocationModel>.broadcast();

  LocationRepositoryImpl(this._locationService);

  @override
  Future<Either<Failure, LocationModel>> getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      final locationModel = LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
      );
      return Right(locationModel);
    } catch (e) {
      return Left(LocationFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> startLocationUpdates() async {
    try {
      final hasPermission = await _locationService.requestPermission();
      if (!hasPermission) {
        return const Left(PermissionFailure('Location permission denied'));
      }

      _positionSubscription = _locationService.positionStream.listen(
        (position) {
          final locationModel = LocationModel(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: position.timestamp,
            accuracy: position.accuracy,
            altitude: position.altitude,
            speed: position.speed,
          );
          _locationController.add(locationModel);
        },
        onError: (error) {
          _locationController.addError(error);
        },
      );

      return const Right(null);
    } catch (e) {
      return Left(LocationFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> stopLocationUpdates() async {
    try {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      return const Right(null);
    } catch (e) {
      return Left(LocationFailure(e.toString()));
    }
  }

  @override
  Stream<LocationModel>? getLocationStream() {
    return _locationController.stream;
  }

  @override
  Future<Either<Failure, List<LocationModel>>> getLocationHistory() async {
    // This would typically fetch from local storage
    // For now, return empty list
    return const Right([]);
  }

  void dispose() {
    _positionSubscription?.cancel();
    _locationController.close();
  }
}
