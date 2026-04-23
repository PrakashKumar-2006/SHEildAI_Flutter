class UserProfileModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String? profilePicture;
  final bool isPremium;
  final DateTime subscriptionExpiry;
  final Map<String, dynamic> preferences;

  UserProfileModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.profilePicture,
    required this.isPremium,
    required this.subscriptionExpiry,
    required this.preferences,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String,
      profilePicture: json['profilePicture'] as String?,
      isPremium: json['isPremium'] as bool? ?? false,
      subscriptionExpiry: DateTime.parse(json['subscriptionExpiry'] as String),
      preferences: json['preferences'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      if (profilePicture != null) 'profilePicture': profilePicture,
      'isPremium': isPremium,
      'subscriptionExpiry': subscriptionExpiry.toIso8601String(),
      'preferences': preferences,
    };
  }

  UserProfileModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? profilePicture,
    bool? isPremium,
    DateTime? subscriptionExpiry,
    Map<String, dynamic>? preferences,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      profilePicture: profilePicture ?? this.profilePicture,
      isPremium: isPremium ?? this.isPremium,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      preferences: preferences ?? this.preferences,
    );
  }

  bool get isSubscriptionActive {
    return DateTime.now().isBefore(subscriptionExpiry);
  }
}
