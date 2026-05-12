class StaticSafetyAlert {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime timestamp;
  final String severity; // 'low', 'medium', 'high'

  StaticSafetyAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.timestamp,
    required this.severity,
  });

  factory StaticSafetyAlert.fromJson(Map<String, dynamic> json) {
    return StaticSafetyAlert(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      severity: json['severity'] ?? 'low',
    );
  }
}

class SafetyTip {
  final String id;
  final String icon;
  final String title;
  final String description;

  SafetyTip({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
  });

  factory SafetyTip.fromJson(Map<String, dynamic> json) {
    return SafetyTip(
      id: json['id'] ?? '',
      icon: json['icon'] ?? 'info',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class AwarenessVideo {
  final String id;
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final String duration;
  final String category;

  AwarenessVideo({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.category,
  });

  factory AwarenessVideo.fromJson(Map<String, dynamic> json) {
    return AwarenessVideo(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      duration: json['duration'] ?? '',
      category: json['category'] ?? '',
    );
  }

  // Helper to extract Youtube ID from URL
  String? get youtubeId {
    final uri = Uri.tryParse(videoUrl);
    if (uri == null) return null;
    if (uri.host.contains('youtube.com')) {
      return uri.queryParameters['v'];
    } else if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    return null;
  }
}

class SafetyCampaign {
  final String id;
  final String title;
  final String venue;
  final String date;
  final String distance;
  final String description;

  SafetyCampaign({
    required this.id,
    required this.title,
    required this.venue,
    required this.date,
    required this.distance,
    required this.description,
  });

  factory SafetyCampaign.fromJson(Map<String, dynamic> json) {
    return SafetyCampaign(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      venue: json['venue'] ?? '',
      date: json['date'] ?? '',
      distance: json['distance'] ?? '',
      description: json['description'] ?? '',
    );
  }
}
