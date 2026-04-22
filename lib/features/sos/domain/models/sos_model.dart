import 'package:equatable/equatable.dart';

class SOSModel extends Equatable {
  final String id;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String status;
  final List<String> contactsNotified;
  final String? message;

  const SOSModel({
    required this.id,
    required this.timestamp,
    this.latitude,
    this.longitude,
    required this.status,
    required this.contactsNotified,
    this.message,
  });

  SOSModel copyWith({
    String? id,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? status,
    List<String>? contactsNotified,
    String? message,
  }) {
    return SOSModel(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      contactsNotified: contactsNotified ?? this.contactsNotified,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'contactsNotified': contactsNotified,
      'message': message,
    };
  }

  factory SOSModel.fromJson(Map<String, dynamic> json) {
    return SOSModel(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      status: json['status'] as String,
      contactsNotified: List<String>.from(json['contactsNotified'] as List),
      message: json['message'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        timestamp,
        latitude,
        longitude,
        status,
        contactsNotified,
        message,
      ];
}
