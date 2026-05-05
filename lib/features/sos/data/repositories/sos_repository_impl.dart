import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/mongo_service.dart';
import '../../../../core/services/sms_service.dart';
import 'package:flutter/foundation.dart';
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

      // --- OPTIONAL BETTER FEATURE: Send SMS to nearby active users ---
      // We do this in a fire-and-forget manner to not block the main SOS flow
      final email = _storageService.getString('user_email') ?? '';
      final identifier = email.isNotEmpty ? email : phone;
      
      _notifyNearbyUsers(latitude, longitude, userName, phone, identifier).catchError((e) {
        debugPrint('[SOS] Error notifying nearby users: $e');
      });

      return Right(sosModel);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  Future<void> _notifyNearbyUsers(double lat, double lon, String victimName, String victimPhone, String victimIdentifier) async {
    try {
      // 1. Fetch nearby users from MongoDB (within 5km)
      final nearbyUsers = await _mongoService.getNearbyUsers(lat, lon, 5.0);
      
      // 2. Filter out the victim themselves
      final others = nearbyUsers.where((u) {
        final phone = u['phone'] as String? ?? '';
        final identifier = u['identifier'] as String? ?? '';
        return phone != victimPhone && identifier != victimIdentifier;
      }).toList();

      if (others.isEmpty) {
        debugPrint('[SOS] No nearby users found within 5km.');
        return;
      }

      debugPrint('[SOS] Found ${others.length} nearby users to alert.');

      // 3. Select top 5 nearest users to avoid massive SMS costs/spam
      final targets = others.take(5).toList();
      final targetPhones = targets.map((u) => u['phone'] as String? ?? '').where((p) => p.isNotEmpty).toList();

      if (targetPhones.isEmpty) return;

      // 4. Send SMS alert
      final locationUrl = 'https://www.google.com/maps?q=$lat,$lon';
      final message = '🚨 SHEild AI: COMMUNITY ALERT 🚨\n$victimName needs help nearby! View live location:\n$locationUrl\nTap "Save the Victim" in your app to respond.';

      debugPrint('[SOS] Sending community SMS to: ${targetPhones.join(", ")}');
      await SMSService().sendBulkSMS(phoneNumbers: targetPhones, message: message);
    } catch (e) {
      debugPrint('[SOS] _notifyNearbyUsers error: $e');
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
