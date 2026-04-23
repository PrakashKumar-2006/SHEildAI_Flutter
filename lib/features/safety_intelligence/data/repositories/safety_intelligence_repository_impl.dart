import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/safety_forecast_model.dart';
import '../../domain/repositories/safety_intelligence_repository.dart';

class SafetyIntelligenceRepositoryImpl implements SafetyIntelligenceRepository {
  SafetyIntelligenceRepositoryImpl();

  @override
  Future<Either<Failure, SafetyForecastModel>> getSafetyForecast({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final result = await ApiService.getSafetyForecast(latitude, longitude);
      
      if (result != null) {
        final forecast = SafetyForecastModel.fromJson(result);
        return Right(forecast);
      } else {
        return const Left(ServerFailure('Failed to get safety forecast'));
      }
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<BestTravelTimeModel>>> getBestTravelTimes({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
  }) async {
    try {
      final result = await ApiService.getBestTravelTime(
        originLat,
        originLon,
        destLat,
        destLon,
      );
      
      if (result != null) {
        final travelTimes = (result['recommendations'] as List)
            .map((e) => BestTravelTimeModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return Right(travelTimes);
      } else {
        return const Left(ServerFailure('Failed to get best travel times'));
      }
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getHotspots({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    try {
      final result = await ApiService.getHotspots(latitude, longitude, radiusKm);
      
      if (result != null) {
        final hotspots = result as List<Map<String, dynamic>>;
        return Right(hotspots);
      } else {
        return const Left(ServerFailure('Failed to get hotspots'));
      }
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }
}
