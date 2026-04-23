class SOSSessionModel {
  final String id;
  final String userId;
  final double latitude;
  final double longitude;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;
  final String? videoPath;
  final List<String> notifiedContacts;
  final String status; // 'active', 'cancelled', 'completed'

  SOSSessionModel({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.startTime,
    this.endTime,
    required this.isActive,
    this.videoPath,
    required this.notifiedContacts,
    required this.status,
  });

  factory SOSSessionModel.fromJson(Map<String, dynamic> json) {
    return SOSSessionModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      isActive: json['isActive'] as bool? ?? false,
      videoPath: json['videoPath'] as String?,
      notifiedContacts: (json['notifiedContacts'] as List<dynamic>).map((e) => e as String).toList(),
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
      'isActive': isActive,
      if (videoPath != null) 'videoPath': videoPath,
      'notifiedContacts': notifiedContacts,
      'status': status,
    };
  }

  SOSSessionModel copyWith({
    String? id,
    String? userId,
    double? latitude,
    double? longitude,
    DateTime? startTime,
    DateTime? endTime,
    bool? isActive,
    String? videoPath,
    List<String>? notifiedContacts,
    String? status,
  }) {
    return SOSSessionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
      videoPath: videoPath ?? this.videoPath,
      notifiedContacts: notifiedContacts ?? this.notifiedContacts,
      status: status ?? this.status,
    );
  }

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }
}
