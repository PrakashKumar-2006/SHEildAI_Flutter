class SubscriptionModel {
  final String id;
  final String userId;
  final String planType; // 'free', 'monthly', 'yearly'
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final double price;
  final String currency;

  SubscriptionModel({
    required this.id,
    required this.userId,
    required this.planType,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.price,
    this.currency = 'USD',
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      planType: json['planType'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      isActive: json['isActive'] as bool,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'planType': planType,
      'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      'isActive': isActive,
      'price': price,
      'currency': currency,
    };
  }

  SubscriptionModel copyWith({
    String? id,
    String? userId,
    String? planType,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    double? price,
    String? currency,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      planType: planType ?? this.planType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      price: price ?? this.price,
      currency: currency ?? this.currency,
    );
  }

  bool get isPremium => planType != 'free';
  bool get isExpired => endDate != null && DateTime.now().isAfter(endDate!);
  int get daysRemaining {
    if (endDate == null) return 0;
    return endDate!.difference(DateTime.now()).inDays;
  }
}
