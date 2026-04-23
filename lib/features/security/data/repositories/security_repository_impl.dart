import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/hive_service.dart';
import '../../domain/models/privacy_settings_model.dart';
import '../../domain/repositories/security_repository.dart';

class SecurityRepositoryImpl implements SecurityRepository {
  final HiveService _hiveService;
  static const String _privacyBoxName = 'privacy_settings';

  SecurityRepositoryImpl(this._hiveService);

  @override
  Future<Either<Failure, PrivacySettingsModel>> getPrivacySettings() async {
    try {
      await _hiveService.openBox(_privacyBoxName);
      
      final data = await _hiveService.get(_privacyBoxName, 'settings');
      if (data != null) {
        final settings = PrivacySettingsModel.fromJson(data as Map<String, dynamic>);
        return Right(settings);
      }
      
      // Return default settings
      final defaultSettings = PrivacySettingsModel(
        shareLocationWithEmergencyContacts: true,
        shareLocationWithCommunity: false,
        allowDataCollection: true,
        enableAnalytics: true,
        enableCrashReporting: true,
      );
      
      return Right(defaultSettings);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PrivacySettingsModel>> updatePrivacySettings(PrivacySettingsModel settings) async {
    try {
      await _hiveService.openBox(_privacyBoxName);
      
      await _hiveService.put(_privacyBoxName, 'settings', settings.toJson());
      
      return Right(settings);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUserData() async {
    try {
      await _hiveService.clearAll();
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearCache() async {
    try {
      await _hiveService.clearLocationLogs();
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
