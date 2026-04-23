import 'package:dartz/dartz.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../../core/error/failures.dart';
import '../../domain/models/subscription_model.dart';
import '../../domain/repositories/subscription_repository.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  @override
  Future<Either<Failure, SubscriptionModel>> getCurrentSubscription(String userId) async {
    try {
      // For now, return a default free subscription
      // In production, this would fetch from backend or local storage
      final subscription = SubscriptionModel(
        id: 'free',
        userId: userId,
        planType: 'free',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 365)),
        isActive: true,
        price: 0.0,
      );
      return Right(subscription);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, SubscriptionModel>> purchaseSubscription({
    required String userId,
    required String planType,
  }) async {
    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        return const Left(NetworkFailure('In-app purchase not available'));
      }

      // Get available products
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(
        _getProductIds(planType),
      );

      if (response.notFoundIDs.isNotEmpty) {
        return Left(NetworkFailure('Products not found: ${response.notFoundIDs}'));
      }

      if (response.productDetails.isEmpty) {
        return const Left(NetworkFailure('No products available'));
      }

      // Purchase the first available product
      final ProductDetails productDetails = response.productDetails.first;
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

      final bool purchaseSuccess = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (purchaseSuccess) {
        final subscription = SubscriptionModel(
          id: productDetails.id,
          userId: userId,
          planType: planType,
          startDate: DateTime.now(),
          endDate: _getEndDate(planType),
          isActive: true,
          price: double.parse(productDetails.price),
        );
        return Right(subscription);
      }

      return const Left(NetworkFailure('Purchase failed'));
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelSubscription(String subscriptionId) async {
    try {
      // In production, this would call the backend to cancel
      // For now, just update local state
      return const Right(null);
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> isPremiumUser(String userId) async {
    try {
      final result = await getCurrentSubscription(userId);
      return result.fold(
        (failure) => Left(failure),
        (subscription) => Right(
          subscription.planType != 'free' && subscription.isActive,
        ),
      );
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  Set<String> _getProductIds(String planType) {
    switch (planType) {
      case 'monthly':
        return {'com.sheildai.subscription.monthly'};
      case 'yearly':
        return {'com.sheildai.subscription.yearly'};
      case 'lifetime':
        return {'com.sheildai.subscription.lifetime'};
      default:
        return {};
    }
  }

  DateTime _getEndDate(String planType) {
    final now = DateTime.now();
    switch (planType) {
      case 'monthly':
        return now.add(const Duration(days: 30));
      case 'yearly':
        return now.add(const Duration(days: 365));
      case 'lifetime':
        return DateTime(2099, 12, 31);
      default:
        return now.add(const Duration(days: 365));
    }
  }
}
