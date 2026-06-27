import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/mongo_service.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../../../core/utils/identity_validator.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final MongoService _mongoService;

  ProfileRepositoryImpl(this._mongoService);

  @override
  Future<Either<Failure, UserProfileModel>> getProfile(String email) async {
    try {
      final userDoc = await _mongoService.getUserByEmail(email);
      if (userDoc != null) {
        // Map Mongo fields to UserProfileModel
        final profileData = Map<String, dynamic>.from(userDoc['profile'] ?? {});
        profileData['id'] = userDoc['_id'].toString();
        profileData['email'] = userDoc['email'];
        profileData['phone'] = IdentityValidator.healPhone(userDoc['phone']?.toString());
        
        // Name priority: 1. Firebase displayName (if we can get it, maybe passed later), 
        // 2. Stored profile name, 3. Email prefix (Last fallback)
        String storedName = userDoc['name']?.toString() ?? '';
        if (storedName.isEmpty || storedName.toLowerCase() == 'user' || storedName == 'Safety Watcher') {
          // Last fallback
          storedName = email.split('@')[0];
        }
        profileData['name'] = storedName;
        
        final profile = UserProfileModel.fromJson(profileData);
        return Right(profile);
      }
      
      // Try fetching from backend
      final response = await ApiService.getUserProfile(email);
      if (response != null) {
        final profile = UserProfileModel.fromJson(response);
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
      final identifier = profile.phone.isNotEmpty ? profile.phone : profile.email;
      // Update on MongoDB
      await _mongoService.updateUser(identifier, {
        'name': profile.name,
        'phone': IdentityValidator.healPhone(profile.phone),
        'profile': profile.toJson(),
      });
      
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
  Future<Either<Failure, void>> updateProfilePicture(String email, String imagePath) async {
    try {
      await _mongoService.updateUser(email, {'profile.profilePicture': imagePath});
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updatePreferences(String email, Map<String, dynamic> preferences) async {
    try {
      await _mongoService.updateUser(email, {'profile.preferences': preferences});
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
