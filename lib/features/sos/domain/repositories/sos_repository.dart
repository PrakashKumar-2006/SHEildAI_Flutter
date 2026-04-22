import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../models/sos_model.dart';

abstract class SOSRepository {
  Future<Either<Failure, SOSModel>> triggerSOS({
    required double latitude,
    required double longitude,
    required List<String> contacts,
    String? message,
  });

  Future<Either<Failure, void>> cancelSOS(String sosId);

  Future<Either<Failure, List<SOSModel>>> getSOSHistory();

  Future<Either<Failure, bool>> isSOSActive();
}
