import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../models/safety_forecast_model.dart';

abstract class SafetyIntelligenceRepository {
  Future<Either<Failure, SafetyForecastModel>> getSafetyForecast({
    required double latitude,
    required double longitude,
  });
  
  Future<Either<Failure, List<BestTravelTimeModel>>> getBestTravelTimes({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
  });
  
  Future<Either<Failure, List<Map<String, dynamic>>>> getHotspots({
    required double latitude,
    required double longitude,
    double radiusKm,
  });
}
