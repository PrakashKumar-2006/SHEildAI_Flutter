import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/hive_service.dart';
import '../../domain/models/alert_model.dart';
import '../../domain/repositories/alert_repository.dart';

class AlertRepositoryImpl implements AlertRepository {
  final HiveService _hiveService;
  static const String _alertsBoxName = 'alerts';
  final StreamController<List<AlertModel>> _alertsController = StreamController<List<AlertModel>>.broadcast();

  AlertRepositoryImpl(this._hiveService);

  @override
  Stream<List<AlertModel>> get alertsStream => _alertsController.stream;

  @override
  Future<Either<Failure, List<AlertModel>>> getAlerts() async {
    try {
      await _hiveService.openBox(_alertsBoxName);
      
      final allData = await _hiveService.getAll(_alertsBoxName);
      final alerts = allData
          .map((data) => AlertModel.fromJson(data as Map<String, dynamic>))
          .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return Right(alerts);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AlertModel>> addAlert(AlertModel alert) async {
    try {
      await _hiveService.openBox(_alertsBoxName);
      
      await _hiveService.put(_alertsBoxName, alert.id, alert.toJson());
      
      // Update stream
      final result = await getAlerts();
      result.fold(
        (failure) => null,
        (alerts) => _alertsController.add(alerts),
      );
      
      return Right(alert);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markAsRead(String alertId) async {
    try {
      await _hiveService.openBox(_alertsBoxName);
      
      final data = await _hiveService.get(_alertsBoxName, alertId);
      if (data != null) {
        final alert = AlertModel.fromJson(data as Map<String, dynamic>);
        final updatedAlert = alert.copyWith(isRead: true);
        await _hiveService.put(_alertsBoxName, alertId, updatedAlert.toJson());
        
        // Update stream
        final result = await getAlerts();
        result.fold(
          (failure) => null,
          (alerts) => _alertsController.add(alerts),
        );
      }
      
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAlert(String alertId) async {
    try {
      await _hiveService.openBox(_alertsBoxName);
      
      await _hiveService.delete(_alertsBoxName, alertId);
      
      // Update stream
      final result = await getAlerts();
      result.fold(
        (failure) => null,
        (alerts) => _alertsController.add(alerts),
      );
      
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearAllAlerts() async {
    try {
      await _hiveService.openBox(_alertsBoxName);
      
      await _hiveService.openBox(_alertsBoxName);
      final box = await _hiveService.getAll(_alertsBoxName);
      for (final data in box) {
        final alertId = data['id'] as String;
        await _hiveService.delete(_alertsBoxName, alertId);
      }
      
      _alertsController.add([]);
      
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  void dispose() {
    _alertsController.close();
  }
}
