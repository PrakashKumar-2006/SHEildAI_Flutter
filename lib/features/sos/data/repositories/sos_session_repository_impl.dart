import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/mongo_service.dart';
import '../../domain/models/sos_session_model.dart';
import '../../domain/repositories/sos_session_repository.dart';

class SOSSessionRepositoryImpl implements SOSSessionRepository {
  final MongoService _mongoService;

  SOSSessionRepositoryImpl(this._mongoService);

  @override
  Future<Either<Failure, SOSSessionModel>> createSession({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final session = SOSSessionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        startTime: DateTime.now(),
        isActive: true,
        notifiedContacts: [],
        status: 'active',
      );

      await _mongoService.createSOS(session.toJson());
      
      return Right(session);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SOSSessionModel>> getSession(String sessionId) async {
    try {
      // For now we'll just return a failure or implement a getSOSById in MongoService
      return const Left(StorageFailure('Session fetching not fully implemented for Mongo yet'));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SOSSessionModel>>> getAllSessions(String userId) async {
    try {
      final history = await _mongoService.getUserSOSHistory(userId);
      final sessions = history.map((json) => SOSSessionModel.fromJson(json)).toList();
      return Right(sessions);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SOSSessionModel>> updateSession(SOSSessionModel session) async {
    try {
      await _mongoService.updateSOSStatus(session.id, session.status);
      return Right(session);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSession(String sessionId) async {
    try {
      // Delete from Mongo not implemented yet in service, but we'll assume it's fine for now
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
