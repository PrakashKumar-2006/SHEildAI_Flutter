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
      sosId: json['sosId'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? 'Someone',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      message: json['message'] ?? 'Emergency SOS!',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
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
        _handleSentinelAlert(data);
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

  void _handleFeedUpdate(Map<String, dynamic> data) {
    _communityFeed.insert(0, {
      ...data,
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
