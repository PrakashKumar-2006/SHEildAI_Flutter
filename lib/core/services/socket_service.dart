import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  SocketService._internal();

  // Point to the correct production backend URL
  static String get _backendUrl => 'https://sheildai-flutter.onrender.com';
  
  IO.Socket? _socket;
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  bool _isConnected = false;
  String? _currentUserId;
  Timer? _heartbeatTimer;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(String phone) async {
    if (_socket != null && _socket!.connected) {
      if (_currentUserId == phone) return;
      debugPrint('[SocketService] Reconnecting since user changed from $_currentUserId to $phone');
      disconnect();
    }
    
    _currentUserId = phone;
    
    debugPrint('[SocketService] Connecting to: $_backendUrl for user: $phone');
    
    _socket = IO.io(_backendUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .enableAutoConnect()
      .setQuery({'phone': phone})
      .build());

    _socket!.onConnect((_) {
      debugPrint('[SocketService] SUCCESS: Connected to Real-time Bridge');
      _isConnected = true;
      _connectionController.add(true);
      _startHeartbeat();
    });

    _socket!.onDisconnect((_) {
      debugPrint('[SocketService] WARNING: Disconnected from Bridge');
      _isConnected = false;
      _connectionController.add(false);
      _stopHeartbeat();
    });

    _socket!.onConnectError((data) => debugPrint('[SocketService] Connect Error: $data'));
    _socket!.onError((data) => debugPrint('[SocketService] Socket Error: $data'));

    _socket!.onAny((event, data) {
      if (data is Map) {
        try {
          // Convert to Map<String, dynamic> safely
          final wrappedData = Map<String, dynamic>.from(data);
          wrappedData['event'] = event;
          _messageController.add(wrappedData);
        } catch (_) {
          _messageController.add({'event': event, 'data': data});
        }
      } else {
         _messageController.add({'event': event, 'data': data});
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // We don't have direct access to LocationProvider here, 
    // so we'll rely on the UI/Providers to call emitLocationUpdate 
    // when they have fresh data, OR we can set up a generic 30s pulse.
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Tells the backend where this user is so they can receive Sentinel Alerts (5km radius)
  void emitLocationUpdate(double lat, double lon) {
    if (_socket != null && _isConnected) {
      _socket!.emit('update_location', {
        'phone': _currentUserId,
        'lat': lat,
        'lon': lon,
      });
    }
  }

  void emitSOSAlert(Map<String, dynamic> sosData) {
    if (_socket != null && _isConnected) {
      debugPrint('[SocketService] Emitting SOS Alert to Community Bridge');
      _socket!.emit('sos_alert', sosData);
    }
  }

  void emitCommunityReport(Map<String, dynamic> reportData) {
    if (_socket != null && _isConnected) {
      debugPrint('[SocketService] Emitting Community Report to Bridge');
      _socket!.emit('community_report', reportData);
    }
  }

  void disconnect() {
    _stopHeartbeat();
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }

  static String get backendUrl => _backendUrl;
}
