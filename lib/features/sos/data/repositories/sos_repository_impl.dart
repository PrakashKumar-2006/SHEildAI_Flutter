import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/models/sos_model.dart';
import '../../domain/repositories/sos_repository.dart';

class SOSRepositoryImpl implements SOSRepository {
  final StorageService _storageService;
  final NotificationService _notificationService;

  SOSRepositoryImpl({
    required StorageService storageService,
    required NotificationService notificationService,
  })  : _storageService = storageService,
        _notificationService = notificationService;

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

      // Save SOS to storage
      final history = await getSOSHistory();
      history.fold(
        (failure) => null,
        (sosList) {
          final updatedList = [sosModel, ...sosList];
          _storageService.setStringList(
            'sos_history',
            updatedList.map((e) => _encodeSOS(e)).toList(),
          );
        },
      );

      // Store active SOS
      await _storageService.setString('active_sos', sosId);
      await _storageService.setLastSosTime(DateTime.now());

      // Show notification
      await _notificationService.showSOSNotification(
        message: sosModel.message ?? 'SOS activated!',
        location: 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}',
      );

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

      // Update SOS status in history
      final history = await getSOSHistory();
      history.fold(
        (failure) => null,
        (sosList) {
          final updatedList = sosList.map((sos) {
            if (sos.id == sosId) {
              return sos.copyWith(status: 'cancelled');
            }
            return sos;
          }).toList();
          _storageService.setStringList(
            'sos_history',
            updatedList.map((e) => _encodeSOS(e)).toList(),
          );
        },
      );

      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SOSModel>>> getSOSHistory() async {
    try {
      final historyJson = _storageService.getStringList('sos_history');
      if (historyJson == null) {
        return const Right([]);
      }

      final sosList = historyJson.map((json) => _decodeSOS(json)).toList();
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

  String _encodeSOS(SOSModel sos) {
    final json = sos.toJson();
    return json.entries.map((e) => '${e.key}:${e.value}').join('|');
  }

  SOSModel _decodeSOS(String encoded) {
    final map = <String, dynamic>{};
    for (final item in encoded.split('|')) {
      final parts = item.split(':');
      if (parts.length == 2) {
        final key = parts[0];
        final value = parts[1];
        if (key == 'timestamp') {
          map[key] = DateTime.parse(value);
        } else if (key == 'latitude' || key == 'longitude') {
          map[key] = double.tryParse(value);
        } else if (key == 'contactsNotified') {
          map[key] = value.split(',');
        } else {
          map[key] = value;
        }
      }
    }
    return SOSModel.fromJson(map);
  }
}
