import 'dart:convert';
import 'dart:math' as math;
import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import '../../../../core/error/failures.dart';
import '../../domain/models/risk_zone_model.dart';
import '../../domain/repositories/risk_zone_repository.dart';

class RiskZoneRepositoryImpl implements RiskZoneRepository {
  static const String _riskDataAsset = 'assets/risk_data.json';

  @override
  Future<Either<Failure, List<RiskZoneModel>>> getRiskZones() async {
    try {
      final jsonString = await rootBundle.loadString(_riskDataAsset);
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      
      final zones = (jsonData['zones'] as List)
          .map((zone) => RiskZoneModel.fromJson(zone as Map<String, dynamic>))
          .toList();
      
      return Right(zones);
    } catch (e) {
      return Left(StorageFailure('Failed to load risk zones: $e'));
    }
  }

  @override
  Future<Either<Failure, double>> calculateRiskAtLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final zonesResult = await getRiskZones();
      
      return zonesResult.fold(
        (failure) => Left(failure),
        (zones) {
          double maxRisk = 0;
          
          for (final zone in zones) {
            final distance = _calculateDistance(
              latitude,
              longitude,
              zone.latitude,
              zone.longitude,
            );
            
            if (distance < zone.radius) {
              final riskImpact = zone.baseScore * (1 - distance / zone.radius);
              if (riskImpact > maxRisk) {
                maxRisk = riskImpact;
              }
            }
          }
          
          return Right(maxRisk);
        },
      );
    } catch (e) {
      return Left(StorageFailure('Failed to calculate risk: $e'));
    }
  }

  @override
  Future<Either<Failure, double>> applyNightTimeMultiplier(double baseRisk) async {
    try {
      final hour = DateTime.now().hour;
      final isNightTime = hour >= 20 || hour < 6;
      
      if (isNightTime) {
        // Apply 1.5x multiplier during night hours
        return Right(baseRisk * 1.5);
      }
      
      return Right(baseRisk);
    } catch (e) {
      return Left(StorageFailure('Failed to apply night time multiplier: $e'));
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.pow(math.sin(dLon / 2), 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }
}
