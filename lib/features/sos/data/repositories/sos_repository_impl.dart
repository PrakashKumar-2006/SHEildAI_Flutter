import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/mongo_service.dart';
import '../../domain/models/sos_model.dart';
import '../../domain/repositories/sos_repository.dart';

class SOSRepositoryImpl implements SOSRepository {
  final StorageService _storageService;
  final NotificationService _notificationService;
  final MongoService _mongoService;

  SOSRepositoryImpl({
    required StorageService storageService,
    required NotificationService notificationService,
    required MongoService mongoService,
  })  : _storageService = storageService,
        _notificationService = notificationService,
        _mongoService = mongoService;

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

      // Store active SOS in session storage (not long-term database)
      await _storageService.setString('active_sos', sosId);
      await _storageService.setLastSosTime(DateTime.now());

      // Show notification
      await _notificationService.showSOSNotification(
        message: sosModel.message ?? 'SOS activated!',
        location: 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
      );

      // Trigger real-time cloud SOS via Socket (Render)
      final phone = _storageService.getString('user_phone') ?? 'unknown';
      final userName = _storageService.getString('user_name') ?? 'Someone';
      
      SocketService().emitSOSAlert({
        'sosId': sosId,
        'userId': phone,
        'name': userName,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'message': sosModel.message,
      });

      // Persist to MongoDB Atlas exclusively
      await _mongoService.createSOS({
        'sos_id': sosId,
        'user_phone': phone,
        'name': userName,
        'latitude': latitude,
        'longitude': longitude,
        'status': 'active',
        'timestamp': DateTime.now().toIso8601String(),
        'contacts': contacts,
      });

      // Standard API trigger (Render)
      ApiService.triggerCloudSOS(phone, latitude, longitude).catchError((_) => null);

      return Right(sosModel);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SOSModel>>> getSOSHistory() async {
    try {
      final phone = _storageService.getString('user_phone') ?? '';
      if (phone.isEmpty) return const Right([]);
      
      final historyData = await _mongoService.getUserSOSHistory(phone);
      final history = historyData.map((json) => SOSModel.fromJson(json)).toList();
      return Right(history);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateSOSStatus(String sosId, String status) async {
    try {
      await _mongoService.updateSOSStatus(sosId, status);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelSOS(String sosId) async {
    try {
      await _mongoService.updateSOSStatus(sosId, 'cancelled');
      await _storageService.remove('active_sos');
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isSOSActive() async {
    try {
      final activeSosId = _storageService.getString('active_sos');
      return Right(activeSosId != null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
