import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/mongo_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/community_report_model.dart';
import '../../domain/repositories/community_repository.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  final MongoService _mongoService = MongoService();

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
      final reportData = {
        'phone': phone,
        'lat': latitude,
        'lon': longitude,
        'incident_type': incidentType,
        'description': description,
        'severity': severity,
        'anonymous': anonymous,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final success = await _mongoService.submitCommunityReport(reportData);

      if (success) {
        // Also sync with Render backend to ensure it triggers its own broadcast logic
        // We don't await this as it's secondary to the direct Mongo save
        ApiService.submitCommunityReport(reportData);

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
        
        // Broadcast to other users via Socket for real-time visibility
        // Ensure anonymity in the broadcast
        SocketService().emitCommunityReport({
          'latitude': latitude,
          'longitude': longitude,
          'incidentType': incidentType,
          'description': description,
          'severity': severity,
          'anonymous': anonymous,
          'reporterName': anonymous ? 'Anonymous' : (StorageService().getString('user_name') ?? 'Community Member'),
          'timestamp': DateTime.now().toIso8601String(),
        });

        return Right(report);
      } else {
        return const Left(ServerFailure('Failed to save report to MongoDB'));
      }
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CommunityReportModel>>> getNearbyReports({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    try {
      final results = await _mongoService.getNearbyReports(latitude, longitude, radiusKm);

      final reports = results
          .map((json) => CommunityReportModel.fromJson(json))
          .toList();
      return Right(reports);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
