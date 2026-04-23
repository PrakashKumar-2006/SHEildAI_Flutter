class PrivacySettingsModel {
  final bool shareLocationWithEmergencyContacts;
  final bool shareLocationWithCommunity;
  final bool allowDataCollection;
  final bool enableAnalytics;
  final bool enableCrashReporting;

  PrivacySettingsModel({
    required this.shareLocationWithEmergencyContacts,
    required this.shareLocationWithCommunity,
    required this.allowDataCollection,
    required this.enableAnalytics,
    required this.enableCrashReporting,
  });

  factory PrivacySettingsModel.fromJson(Map<String, dynamic> json) {
    return PrivacySettingsModel(
      shareLocationWithEmergencyContacts: json['shareLocationWithEmergencyContacts'] as bool? ?? true,
      shareLocationWithCommunity: json['shareLocationWithCommunity'] as bool? ?? false,
      allowDataCollection: json['allowDataCollection'] as bool? ?? true,
      enableAnalytics: json['enableAnalytics'] as bool? ?? true,
      enableCrashReporting: json['enableCrashReporting'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shareLocationWithEmergencyContacts': shareLocationWithEmergencyContacts,
      'shareLocationWithCommunity': shareLocationWithCommunity,
      'allowDataCollection': allowDataCollection,
      'enableAnalytics': enableAnalytics,
      'enableCrashReporting': enableCrashReporting,
    };
  }

  PrivacySettingsModel copyWith({
    bool? shareLocationWithEmergencyContacts,
    bool? shareLocationWithCommunity,
    bool? allowDataCollection,
    bool? enableAnalytics,
    bool? enableCrashReporting,
  }) {
    return PrivacySettingsModel(
      shareLocationWithEmergencyContacts: shareLocationWithEmergencyContacts ?? this.shareLocationWithEmergencyContacts,
      shareLocationWithCommunity: shareLocationWithCommunity ?? this.shareLocationWithCommunity,
      allowDataCollection: allowDataCollection ?? this.allowDataCollection,
      enableAnalytics: enableAnalytics ?? this.enableAnalytics,
      enableCrashReporting: enableCrashReporting ?? this.enableCrashReporting,
    );
  }
}
