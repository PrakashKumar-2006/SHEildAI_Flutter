class CommunityReportModel {
  final String id;
  final double latitude;
  final double longitude;
  final String incidentType;
  final String description;
  final int severity;
  final bool anonymous;
  final DateTime timestamp;
  final String? reporterName;

  CommunityReportModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.incidentType,
    required this.description,
    required this.severity,
    required this.anonymous,
    required this.timestamp,
    this.reporterName,
  });

  factory CommunityReportModel.fromJson(Map<String, dynamic> json) {
    return CommunityReportModel(
      id: json['id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      incidentType: json['incidentType'] as String,
      description: json['description'] as String,
      severity: json['severity'] as int,
      anonymous: json['anonymous'] as bool? ?? true,
      timestamp: DateTime.parse(json['timestamp'] as String),
      reporterName: json['reporterName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'incidentType': incidentType,
      'description': description,
      'severity': severity,
      'anonymous': anonymous,
      'timestamp': timestamp.toIso8601String(),
      if (reporterName != null) 'reporterName': reporterName,
    };
  }

  CommunityReportModel copyWith({
    String? id,
    double? latitude,
    double? longitude,
    String? incidentType,
    String? description,
    int? severity,
    bool? anonymous,
    DateTime? timestamp,
    String? reporterName,
  }) {
    return CommunityReportModel(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      incidentType: incidentType ?? this.incidentType,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      anonymous: anonymous ?? this.anonymous,
      timestamp: timestamp ?? this.timestamp,
      reporterName: reporterName ?? this.reporterName,
    );
  }
}
