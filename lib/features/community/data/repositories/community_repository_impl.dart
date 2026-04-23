import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/community_report_model.dart';
import '../../domain/repositories/community_repository.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  CommunityRepositoryImpl();

  @override
  Future<Either<Failure, CommunityReportModel>> submitReport({
    required String phone,
    required double latitude,
    required double longitude,
    required String incidentType,
    required String description,
    required int severity,
    bool anonymous = true,
  }) async {
    try {
      final result = await ApiService.submitCommunityReport(
        phone,
        latitude,
        longitude,
        incidentType,
        description,
        severity,
        anonymous: anonymous,
      );

      if (result != null) {
        final report = CommunityReportModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          latitude: latitude,
          longitude: longitude,
          incidentType: incidentType,
          description: description,
          severity: severity,
          anonymous: anonymous,
          timestamp: DateTime.now(),
        );
        return Right(report);
      } else {
        return const Left(ServerFailure('Failed to submit community report'));
      }
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CommunityReportModel>>> getNearbyReports({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    try {
      final result = await ApiService.fetchNearbyCommunityReports(latitude, longitude);

      if (result != null) {
        final reports = result
            .map((json) => CommunityReportModel.fromJson(json))
            .toList();
        return Right(reports);
      } else {
        return const Right([]);
      }
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }
}
