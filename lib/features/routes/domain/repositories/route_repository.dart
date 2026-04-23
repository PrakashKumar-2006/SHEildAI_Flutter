import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../models/route_model.dart';

abstract class RouteRepository {
  Future<Either<Failure, List<RouteModel>>> fetchRoutes({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
  });
  
  Future<Either<Failure, Map<String, double>?>> geocodeDestination(String destination, double lat, double lon);
}
