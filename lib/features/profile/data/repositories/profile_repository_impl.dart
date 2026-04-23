import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final HiveService _hiveService;
  static const String _profileBoxName = 'user_profile';

  ProfileRepositoryImpl(this._hiveService);

  @override
  Future<Either<Failure, UserProfileModel>> getProfile(String userId) async {
    try {
      await _hiveService.openBox(_profileBoxName);
      
      final data = await _hiveService.get(_profileBoxName, userId);
      if (data != null) {
        final profile = UserProfileModel.fromJson(data as Map<String, dynamic>);
        return Right(profile);
      }
      
      // Try fetching from backend
      final response = await ApiService.getUserProfile(userId);
      if (response != null) {
        final profile = UserProfileModel.fromJson(response);
        await _hiveService.put(_profileBoxName, userId, profile.toJson());
        return Right(profile);
      }
      
      return const Left(StorageFailure('Profile not found'));
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserProfileModel>> updateProfile(UserProfileModel profile) async {
    try {
      await _hiveService.openBox(_profileBoxName);
      
      // Update local storage
      await _hiveService.put(_profileBoxName, profile.id, profile.toJson());
      
      // Update on backend
      final response = await ApiService.updateUserProfile(profile.toJson());
      if (response != null) {
        final updatedProfile = UserProfileModel.fromJson(response);
        return Right(updatedProfile);
      }
      
      return Right(profile);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateProfilePicture(String userId, String imagePath) async {
    try {
      await _hiveService.openBox(_profileBoxName);
      
      final data = await _hiveService.get(_profileBoxName, userId);
      if (data != null) {
        final profile = UserProfileModel.fromJson(data as Map<String, dynamic>);
        final updatedProfile = profile.copyWith(profilePicture: imagePath);
        await _hiveService.put(_profileBoxName, userId, updatedProfile.toJson());
      }
      
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updatePreferences(String userId, Map<String, dynamic> preferences) async {
    try {
      await _hiveService.openBox(_profileBoxName);
      
      final data = await _hiveService.get(_profileBoxName, userId);
      if (data != null) {
        final profile = UserProfileModel.fromJson(data as Map<String, dynamic>);
        final updatedProfile = profile.copyWith(preferences: preferences);
        await _hiveService.put(_profileBoxName, userId, updatedProfile.toJson());
      }
      
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
