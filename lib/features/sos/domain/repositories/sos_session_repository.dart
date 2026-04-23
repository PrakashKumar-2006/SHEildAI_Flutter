import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../models/sos_session_model.dart';

abstract class SOSSessionRepository {
  Future<Either<Failure, SOSSessionModel>> createSession({
    required String userId,
    required double latitude,
    required double longitude,
  });
  
  Future<Either<Failure, SOSSessionModel>> getSession(String sessionId);
  
  Future<Either<Failure, List<SOSSessionModel>>> getAllSessions(String userId);
  
  Future<Either<Failure, SOSSessionModel>> updateSession(SOSSessionModel session);
  
  Future<Either<Failure, void>> deleteSession(String sessionId);
  
  Future<Either<Failure, SOSSessionModel>> getActiveSession(String userId);
  
  Future<Either<Failure, void>> endSession(String sessionId);
}
