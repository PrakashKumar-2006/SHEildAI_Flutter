import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../models/alert_model.dart';

abstract class AlertRepository {
  Future<Either<Failure, List<AlertModel>>> getAlerts();
  
  Future<Either<Failure, AlertModel>> addAlert(AlertModel alert);
  
  Future<Either<Failure, void>> markAsRead(String alertId);
  
  Future<Either<Failure, void>> deleteAlert(String alertId);
  
  Future<Either<Failure, void>> clearAllAlerts();
  
  Stream<List<AlertModel>> get alertsStream;
}
