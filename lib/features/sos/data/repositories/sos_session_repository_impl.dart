import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/hive_service.dart';
import '../../domain/models/sos_session_model.dart';
import '../../domain/repositories/sos_session_repository.dart';

class SOSSessionRepositoryImpl implements SOSSessionRepository {
  final HiveService _hiveService;
  static const String _sessionBoxName = 'sos_sessions';

  SOSSessionRepositoryImpl(this._hiveService);

  @override
  Future<Either<Failure, SOSSessionModel>> createSession({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _hiveService.openBox(_sessionBoxName);
      
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

      await _hiveService.put(_sessionBoxName, session.id, session.toJson());
      
      return Right(session);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SOSSessionModel>> getSession(String sessionId) async {
    try {
      await _hiveService.openBox(_sessionBoxName);
      
      final data = await _hiveService.get(_sessionBoxName, sessionId);
      if (data == null) {
        return const Left(StorageFailure('Session not found'));
      }

      final session = SOSSessionModel.fromJson(data as Map<String, dynamic>);
      return Right(session);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SOSSessionModel>>> getAllSessions(String userId) async {
    try {
      await _hiveService.openBox(_sessionBoxName);
      
      final allData = await _hiveService.getAll(_sessionBoxName);
      final sessions = allData
          .where((data) => data['userId'] == userId)
          .map((data) => SOSSessionModel.fromJson(data as Map<String, dynamic>))
          .toList()
          ..sort((a, b) => b.startTime.compareTo(a.startTime));

      return Right(sessions);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SOSSessionModel>> updateSession(SOSSessionModel session) async {
    try {
      await _hiveService.openBox(_sessionBoxName);
      
      await _hiveService.put(_sessionBoxName, session.id, session.toJson());
      
      return Right(session);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSession(String sessionId) async {
    try {
      await _hiveService.openBox(_sessionBoxName);
      
      await _hiveService.delete(_sessionBoxName, sessionId);
      
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SOSSessionModel>> getActiveSession(String userId) async {
    try {
      await _hiveService.openBox(_sessionBoxName);
      
      final allData = await _hiveService.getAll(_sessionBoxName);
      final activeSession = allData
          .where((data) => data['userId'] == userId && data['isActive'] == true)
          .map((data) => SOSSessionModel.fromJson(data as Map<String, dynamic>))
          .firstOrNull;

      if (activeSession == null) {
        return const Left(StorageFailure('No active session found'));
      }

      return Right(activeSession);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> endSession(String sessionId) async {
    try {
      final result = await getSession(sessionId);
      
      return result.fold(
        (failure) => Left(failure),
        (session) async {
          final updatedSession = session.copyWith(
            isActive: false,
            endTime: DateTime.now(),
            status: 'completed',
          );
          
          await updateSession(updatedSession);
          return const Right(null);
        },
      );
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
