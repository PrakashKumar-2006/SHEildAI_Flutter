import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../models/privacy_settings_model.dart';

abstract class SecurityRepository {
  Future<Either<Failure, PrivacySettingsModel>> getPrivacySettings();
  
  Future<Either<Failure, PrivacySettingsModel>> updatePrivacySettings(PrivacySettingsModel settings);
  
  Future<Either<Failure, void>> deleteUserData();
  
  Future<Either<Failure, void>> clearCache();
}
