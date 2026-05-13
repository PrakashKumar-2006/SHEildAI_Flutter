import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/notification_service.dart';

class SentinelAlert {
  final String sosId;
  final String userId;
  final String name;
  final double latitude;
  final double longitude;
  final String message;
  final double distance;
  final DateTime timestamp;

  SentinelAlert({
    required this.sosId,
    required this.userId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.message,
    required this.distance,
    required this.timestamp,
  });

  factory SentinelAlert.fromJson(Map<String, dynamic> json) {
    return SentinelAlert(
      sosId: json['sosId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Someone',
      latitude: double.tryParse(json['latitude']?.toString() ?? json['lat']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? json['lon']?.toString() ?? '0') ?? 0.0,
      message: json['message']?.toString() ?? 'Emergency SOS!',
      distance: double.tryParse(json['distance']?.toString() ?? '0') ?? 0.0,
      timestamp: json['timestamp'] != null 
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now() 
          : DateTime.now(),
    );
  }
}

class SentinelProvider extends ChangeNotifier {
  final SocketService _socketService;
  final List<SentinelAlert> _activeAlerts = [];
  final List<Map<String, dynamic>> _communityFeed = [];
  
  StreamSubscription? _socketSub;
  SentinelAlert? _pendingPopup;

  SentinelProvider({required SocketService socketService}) 
      : _socketService = socketService {
    _init();
  }

  List<SentinelAlert> get activeAlerts => _activeAlerts;
  List<Map<String, dynamic>> get communityFeed => _communityFeed;
  SentinelAlert? get pendingPopup => _pendingPopup;

  void _init() {
    _socketSub = _socketService.messageStream.listen((data) {
      final event = data['event'];
      
      if (event == 'sentinel_alert') {
        final payload = data['data'] ?? data;
        _handleSentinelAlert(payload);
      } else if (event == 'community_feed_update' || event == 'new_community_report') {
        _handleFeedUpdate(data);
      }
    });
  }

  void _handleSentinelAlert(Map<String, dynamic> data) {
    final alert = SentinelAlert.fromJson(data);
    
    // Add to active alerts if not already there
    if (!_activeAlerts.any((a) => a.sosId == alert.sosId)) {
      _activeAlerts.insert(0, alert);
      _pendingPopup = alert;
      
      // Also trigger a system notification for background awareness
      NotificationService().showCommunitySOSNotification(
        name: alert.name,
        distanceMeters: alert.distance * 1000,
      );
      
      notifyListeners();
    }
  }

    final payload = data['data'] ?? data;
    _communityFeed.insert(0, {
      ...payload,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'receivedAt': DateTime.now().toIso8601String(),
    });
    
    // Keep feed manageable
    if (_communityFeed.length > 50) _communityFeed.removeLast();
    
    notifyListeners();
  }

  void dismissPopup() {
    _pendingPopup = null;
    notifyListeners();
  }

  void removeAlert(String sosId) {
    _activeAlerts.removeWhere((a) => a.sosId == sosId);
    if (_pendingPopup?.sosId == sosId) _pendingPopup = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }
}
