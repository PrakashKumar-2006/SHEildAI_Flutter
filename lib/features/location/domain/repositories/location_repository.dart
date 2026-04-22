import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../models/location_model.dart';

abstract class LocationRepository {
  Future<Either<Failure, LocationModel>> getCurrentLocation();

  Future<Either<Failure, void>> startLocationUpdates();

  Future<Either<Failure, void>> stopLocationUpdates();

  Stream<LocationModel>? getLocationStream();

  Future<Either<Failure, List<LocationModel>>> getLocationHistory();
}
