class RouteModel {
  final String id;
  final List<Map<String, double>> points;
  final int riskLevel;
  final String safetyLabel;
  final String duration;
  final String distance;
  final String type;

  RouteModel({
    required this.id,
    required this.points,
    required this.riskLevel,
    required this.safetyLabel,
    required this.duration,
    required this.distance,
    required this.type,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      points: (json['points'] as List)
          .map((e) => Map<String, double>.from(e as Map))
          .toList(),
      riskLevel: json['riskLevel'] as int,
      safetyLabel: json['safetyLabel'] as String,
      duration: json['duration'] as String,
      distance: json['distance'] as String,
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'points': points,
      'riskLevel': riskLevel,
      'safetyLabel': safetyLabel,
      'duration': duration,
      'distance': distance,
      'type': type,
    };
  }

  RouteModel copyWith({
    String? id,
    List<Map<String, double>>? points,
    int? riskLevel,
    String? safetyLabel,
    String? duration,
    String? distance,
    String? type,
  }) {
    return RouteModel(
      id: id ?? this.id,
      points: points ?? this.points,
      riskLevel: riskLevel ?? this.riskLevel,
      safetyLabel: safetyLabel ?? this.safetyLabel,
      duration: duration ?? this.duration,
      distance: distance ?? this.distance,
      type: type ?? this.type,
    );
  }
}
