class SafetyForecastModel {
  final String location;
  final String date;
  final double riskLevel;
  final String riskLabel;
  final List<HourlyRisk> hourlyRisks;

  SafetyForecastModel({
    required this.location,
    required this.date,
    required this.riskLevel,
    required this.riskLabel,
    required this.hourlyRisks,
  });

  factory SafetyForecastModel.fromJson(Map<String, dynamic> json) {
    return SafetyForecastModel(
      location: json['location'] as String,
      date: json['date'] as String,
      riskLevel: (json['riskLevel'] as num).toDouble(),
      riskLabel: json['riskLabel'] as String,
      hourlyRisks: (json['hourlyRisks'] as List)
          .map((e) => HourlyRisk.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location': location,
      'date': date,
      'riskLevel': riskLevel,
      'riskLabel': riskLabel,
      'hourlyRisks': hourlyRisks.map((e) => e.toJson()).toList(),
    };
  }
}

class HourlyRisk {
  final int hour;
  final double riskLevel;
  final String riskLabel;

  HourlyRisk({
    required this.hour,
    required this.riskLevel,
    required this.riskLabel,
  });

  factory HourlyRisk.fromJson(Map<String, dynamic> json) {
    return HourlyRisk(
      hour: json['hour'] as int,
      riskLevel: (json['riskLevel'] as num).toDouble(),
      riskLabel: json['riskLabel'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'riskLevel': riskLevel,
      'riskLabel': riskLabel,
    };
  }
}

class BestTravelTimeModel {
  final String departureTime;
  final double estimatedRisk;
  final String riskLabel;
  final int durationMinutes;

  BestTravelTimeModel({
    required this.departureTime,
    required this.estimatedRisk,
    required this.riskLabel,
    required this.durationMinutes,
  });

  factory BestTravelTimeModel.fromJson(Map<String, dynamic> json) {
    return BestTravelTimeModel(
      departureTime: json['departureTime'] as String,
      estimatedRisk: (json['estimatedRisk'] as num).toDouble(),
      riskLabel: json['riskLabel'] as String,
      durationMinutes: json['durationMinutes'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'departureTime': departureTime,
      'estimatedRisk': estimatedRisk,
      'riskLabel': riskLabel,
      'durationMinutes': durationMinutes,
    };
  }
}
