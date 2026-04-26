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
      id: (json['_id'] ?? json['report_id'] ?? json['id'] ?? '').toString(),
      latitude: (json['lat'] ?? json['latitude'] as num).toDouble(),
      longitude: (json['lon'] ?? json['longitude'] as num).toDouble(),
      incidentType: (json['incident_type'] ?? json['incidentType'] ?? 'Other').toString(),
      description: (json['description'] ?? '').toString(),
      severity: (json['severity'] ?? 5) as int,
      anonymous: json['anonymous'] as bool? ?? true,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'].toString()) 
          : (json['created_at'] != null 
              ? DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int) 
              : DateTime.now()),
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
