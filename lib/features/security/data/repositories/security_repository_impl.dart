import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/mongo_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/privacy_settings_model.dart';
import '../../domain/repositories/security_repository.dart';

class SecurityRepositoryImpl implements SecurityRepository {
  final MongoService _mongoService;
  final StorageService _storageService;

  SecurityRepositoryImpl(this._mongoService, this._storageService);

  String get _userEmail => _storageService.getString(AppConstants.keyUserEmail) ?? '';

  @override
  Future<Either<Failure, PrivacySettingsModel>> getPrivacySettings() async {
    try {
      if (_userEmail.isEmpty) return Right(_getDefaultSettings());
      
      final userDoc = await _mongoService.getUserByEmail(_userEmail);
      if (userDoc != null && userDoc['profile'] != null && userDoc['profile']['privacySettings'] != null) {
        final settings = PrivacySettingsModel.fromJson(userDoc['profile']['privacySettings']);
        return Right(settings);
      }
      
      return Right(_getDefaultSettings());
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  PrivacySettingsModel _getDefaultSettings() {
    return PrivacySettingsModel(
      shareLocationWithEmergencyContacts: true,
      shareLocationWithCommunity: false,
      allowDataCollection: true,
      enableAnalytics: true,
      enableCrashReporting: true,
    );
  }

  @override
  Future<Either<Failure, PrivacySettingsModel>> updatePrivacySettings(PrivacySettingsModel settings) async {
    try {
      if (_userEmail.isNotEmpty) {
        await _mongoService.updateUser(_userEmail, {
          'profile.privacySettings': settings.toJson(),
        });
      }
      return Right(settings);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUserData() async {
    try {
      // In a real cloud-only app, this would delete the user from MongoDB
      // For now, let's just clear the local session
      await _storageService.clear();
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearCache() async {
    // No local cache to clear anymore
    return const Right(null);
  }
}
