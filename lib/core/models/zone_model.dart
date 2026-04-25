import 'package:latlong2/latlong.dart';

enum ZoneType {
  safe,
  moderate,
  high,
  critical,
  none,
  notAvailable,
}

class ZoneModel {
  final String id;
  final String name;
  final LatLng center;
  final double radius; // in km
  final int riskScore;
  final ZoneType zoneType;
  final String description;

  ZoneModel({
    required this.id,
    required this.name,
    required this.center,
    required this.radius,
    required this.riskScore,
    required this.zoneType,
    this.description = '',
  });

  factory ZoneModel.fromRiskScore(
    String id,
    String name,
    LatLng center,
    double radius,
    int riskScore,
  ) {
    ZoneType zoneType;
    if (riskScore >= 0 && riskScore <= 25) {
      zoneType = ZoneType.safe;
    } else if (riskScore >= 26 && riskScore <= 50) {
      zoneType = ZoneType.moderate;
    } else if (riskScore >= 51 && riskScore <= 75) {
      zoneType = ZoneType.high;
    } else if (riskScore >= 76 && riskScore <= 100) {
      zoneType = ZoneType.critical;
    } else {
      zoneType = ZoneType.none;
    }

    return ZoneModel(
      id: id,
      name: name,
      center: center,
      radius: radius,
      riskScore: riskScore,
      zoneType: zoneType,
    );
  }

  String get zoneLabel {
    switch (zoneType) {
      case ZoneType.safe:
        return 'Safe Zone';
      case ZoneType.moderate:
        return 'Moderate Zone';
      case ZoneType.high:
        return 'High Risk Zone';
      case ZoneType.critical:
        return 'Critical Zone';
      case ZoneType.none:
        return 'Safe Zone';
      case ZoneType.notAvailable:
        return 'Data Not Available';
    }
  }

  String get zoneColor {
    switch (zoneType) {
      case ZoneType.safe:
        return '#43A047'; // Green
      case ZoneType.moderate:
        return '#F39C12'; // Yellow
      case ZoneType.high:
        return '#E74C3C'; // Red
      case ZoneType.critical:
        return '#8B0000'; // Dark Red
      case ZoneType.none:
        return '#43A047'; // Green (outside any zone)
      case ZoneType.notAvailable:
        return '#9E9E9E'; // Gray
    }
  }

  bool get requiresAlert {
    return zoneType == ZoneType.moderate || 
           zoneType == ZoneType.high || 
           zoneType == ZoneType.critical;
  }

  String get alertMessage {
    switch (zoneType) {
      case ZoneType.moderate:
        return '⚠️ CAUTION: You are entering a Moderate Risk Zone. Stay alert.';
      case ZoneType.high:
        return '🚨 WARNING: You are entering a High Risk Zone. Consider an alternative route.';
      case ZoneType.critical:
        return '🚨🚨 DANGER: You are entering a Critical Zone! Avoid this area if possible.';
      default:
        return '';
    }
  }
}
