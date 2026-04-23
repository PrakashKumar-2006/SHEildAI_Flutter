import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../models/community_report_model.dart';

abstract class CommunityRepository {
  Future<Either<Failure, CommunityReportModel>> submitReport({
    required String phone,
    required double latitude,
    required double longitude,
    required String incidentType,
    required String description,
    required int severity,
    bool anonymous,
  });
  
  Future<Either<Failure, List<CommunityReportModel>>> getNearbyReports({
    required double latitude,
    required double longitude,
    double radiusKm,
  });
}
