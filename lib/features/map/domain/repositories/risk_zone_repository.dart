import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../models/risk_zone_model.dart';

abstract class RiskZoneRepository {
  Future<Either<Failure, List<RiskZoneModel>>> getRiskZones();
  
  Future<Either<Failure, double>> calculateRiskAtLocation({
    required double latitude,
    required double longitude,
  });
  
  Future<Either<Failure, double>> applyNightTimeMultiplier(double baseRisk);
}
