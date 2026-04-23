import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/route_service.dart';
import '../../domain/models/route_model.dart';
import '../../domain/repositories/route_repository.dart';

class RouteRepositoryImpl implements RouteRepository {
  RouteRepositoryImpl();

  @override
  Future<Either<Failure, List<RouteModel>>> fetchRoutes({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
  }) async {
    try {
      final riskZones = await RouteService.getRiskZones();
      
      final routesData = await RouteService.fetchOSRMRoutes(
        originLat,
        originLon,
        destLat,
        destLon,
        riskZones,
      );

      final routes = routesData.map((routeData) {
        return RouteModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          points: (routeData['points'] as List)
              .map((e) => Map<String, double>.from(e as Map))
              .toList(),
          riskLevel: routeData['riskLevel'] as int,
          safetyLabel: routeData['safetyLabel'] as String,
          duration: routeData['duration'] as String,
          distance: routeData['distance'] as String,
          type: routeData['type'] as String,
        );
      }).toList();

      return Right(routes);
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, double>?>> geocodeDestination(String destination, double lat, double lon) async {
    try {
      final result = await RouteService.geocodeDestination(destination, lat, lon);
      if (result != null) {
        return Right(result);
      }
      return const Left(NetworkFailure('Failed to geocode destination'));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }
}
