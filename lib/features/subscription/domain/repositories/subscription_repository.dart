import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../models/subscription_model.dart';

abstract class SubscriptionRepository {
  Future<Either<Failure, SubscriptionModel>> getCurrentSubscription(String userId);
  
  Future<Either<Failure, SubscriptionModel>> purchaseSubscription({
    required String userId,
    required String planType,
  });
  
  Future<Either<Failure, void>> cancelSubscription(String subscriptionId);
  
  Future<Either<Failure, bool>> isPremiumUser(String userId);
}
