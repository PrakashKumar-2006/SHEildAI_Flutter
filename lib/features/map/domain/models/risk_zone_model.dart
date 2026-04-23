class RiskZoneModel {
  final double latitude;
  final double longitude;
  final double baseScore;
  final double radius; // in kilometers

  RiskZoneModel({
    required this.latitude,
    required this.longitude,
    required this.baseScore,
    this.radius = 1.2,
  });

  factory RiskZoneModel.fromJson(Map<String, dynamic> json) {
    return RiskZoneModel(
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
      baseScore: (json['base_score'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': latitude,
      'lon': longitude,
      'base_score': baseScore,
    };
  }

  RiskZoneModel copyWith({
    double? latitude,
    double? longitude,
    double? baseScore,
    double? radius,
  }) {
    return RiskZoneModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      baseScore: baseScore ?? this.baseScore,
      radius: radius ?? this.radius,
    );
  }
}
