import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/sos_model.dart';
import '../../domain/repositories/sos_repository.dart';

class SOSRepositoryImpl implements SOSRepository {
  final StorageService _storageService;
  final NotificationService _notificationService;
  final HiveService _hiveService;
  final SyncService _syncService;

  SOSRepositoryImpl({
    required StorageService storageService,
    required NotificationService notificationService,
    required HiveService hiveService,
    required SyncService syncService,
  })  : _storageService = storageService,
        _notificationService = notificationService,
        _hiveService = hiveService,
        _syncService = syncService;

  @override
  Future<Either<Failure, SOSModel>> triggerSOS({
    required double latitude,
    required double longitude,
    required List<String> contacts,
    String? message,
  }) async {
    try {
      final sosId = DateTime.now().millisecondsSinceEpoch.toString();
      final sosModel = SOSModel(
        id: sosId,
        timestamp: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        status: 'active',
        contactsNotified: contacts,
        message: message ?? 'SOS activated! Emergency assistance needed.',
      );

      // Save SOS to Hive storage
      await _hiveService.saveSOS(sosModel.toJson());

      // Add to sync queue for offline support
      await _syncService.addToQueue({
        'type': 'sos_triggered',
        'data': sosModel.toJson(),
      });

      // Store active SOS
      await _storageService.setString('active_sos', sosId);
      await _storageService.setLastSosTime(DateTime.now());

      // Show notification
      await _notificationService.showSOSNotification(
        message: sosModel.message ?? 'SOS activated!',
        location: 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
      );

      // Trigger cloud SOS
      final userId = _storageService.getString('user_id') ?? 'unknown';
      ApiService.triggerCloudSOS(userId, latitude, longitude).catchError((_) => null);

      return Right(sosModel);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelSOS(String sosId) async {
    try {
      await _storageService.remove('active_sos');
      await _notificationService.cancelSOSNotifications();

      // Update SOS status in Hive storage
      await _hiveService.updateSOSStatus(sosId, 'cancelled');

      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SOSModel>>> getSOSHistory() async {
    try {
      final historyData = await _hiveService.getSOSHistory();
      final sosList = historyData.map((json) => SOSModel.fromJson(json)).toList();
      return Right(sosList);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isSOSActive() async {
    try {
      final activeSOS = _storageService.getString('active_sos');
      return Right(activeSOS != null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

}
