import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/mongo_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/models/alert_model.dart';
import '../../domain/repositories/alert_repository.dart';

class AlertRepositoryImpl implements AlertRepository {
  final MongoService _mongoService;
  final StorageService _storageService;
  final StreamController<List<AlertModel>> _alertsController = StreamController<List<AlertModel>>.broadcast();

  AlertRepositoryImpl(this._mongoService, this._storageService);

  String get _userEmail => _storageService.getString('user_phone') ?? '';

  @override
  Stream<List<AlertModel>> get alertsStream => _alertsController.stream;

  @override
  Future<Either<Failure, List<AlertModel>>> getAlerts() async {
    try {
      if (_userEmail.isEmpty) return const Right([]);
      
      final allData = await _mongoService.getAlerts(_userEmail);
      final alerts = allData.map((data) {
        final Map<String, dynamic> mappedJson = Map.from(data);
        if (data['_id'] != null) {
          mappedJson['id'] = data['_id'].toString();
        }
        return AlertModel.fromJson(mappedJson);
      }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      _alertsController.add(alerts);
      return Right(alerts);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AlertModel>> addAlert(AlertModel alert) async {
    try {
      if (_userEmail.isEmpty) return Left(StorageFailure('User not logged in'));
      
      final alertData = alert.toJson();
      alertData['user_email'] = _userEmail;
      
      await _mongoService.createAlert(alertData);
      
      // Update stream
      await getAlerts();
      
      return Right(alert);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markAsRead(String alertId) async {
    try {
      await _mongoService.updateAlert(alertId, {'isRead': true});
      
      // Update stream
      await getAlerts();
      
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAlert(String alertId) async {
    try {
      await _mongoService.deleteAlert(alertId);
      
      // Update stream
      await getAlerts();
      
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearAllAlerts() async {
    try {
      // For simplicity, we'll delete them one by one or add a clearAll method to MongoService
      // For now, let's just use the existing getAlerts and delete loop
      final alertsResult = await getAlerts();
      await alertsResult.fold(
        (failure) async => null,
        (alerts) async {
          for (var alert in alerts) {
            await _mongoService.deleteAlert(alert.id);
          }
        },
      );
      
      _alertsController.add([]);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
