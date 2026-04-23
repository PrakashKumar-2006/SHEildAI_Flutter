import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../models/user_profile_model.dart';

abstract class ProfileRepository {
  Future<Either<Failure, UserProfileModel>> getProfile(String userId);
  
  Future<Either<Failure, UserProfileModel>> updateProfile(UserProfileModel profile);
  
  Future<Either<Failure, void>> updateProfilePicture(String userId, String imagePath);
  
  Future<Either<Failure, void>> updatePreferences(String userId, Map<String, dynamic> preferences);
}
