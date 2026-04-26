import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  SocketService._internal();

  static const String _backendUrl = 'https://sheildai1-o.onrender.com';
  
  IO.Socket? _socket;
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  bool _isConnected = false;
  String? _currentUserId;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(String phone) async {
    if (_socket != null && _socket!.connected) return;
    
    _currentUserId = phone;
    
    _socket = IO.io(_backendUrl, IO.OptionBuilder()
      .setTransports(['websocket']) // for Flutter or Web
      .enableAutoConnect()
      .setQuery({'phone': phone})
      .build());

    _socket!.onConnect((_) {
      debugPrint('[SocketService] Connected');
      _isConnected = true;
      _connectionController.add(true);
    });

    _socket!.onDisconnect((_) {
      debugPrint('[SocketService] Disconnected');
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onConnectError((data) => debugPrint('[SocketService] Connect Error: $data'));
    _socket!.onError((data) => debugPrint('[SocketService] Error: $data'));

    // Listen for all events and pipe to messageStream
    _socket!.onAny((event, data) {
      if (data is Map<String, dynamic>) {
        // Wrap with event name for easier handling in providers
        final wrappedData = Map<String, dynamic>.from(data);
        wrappedData['event'] = event;
        _messageController.add(wrappedData);
      } else if (data is String) {
        try {
          final decoded = Map<String, dynamic>.from({'data': data, 'event': event});
          _messageController.add(decoded);
        } catch (_) {}
      }
    });
  }

  void joinSOSRoom(String sosId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('join_sos', {
        'sosId': sosId,
        'userId': _currentUserId,
      });
    }
  }

  void emitLiveLocationUpdate(String sosId, double lat, double lng) {
    if (_socket != null && _isConnected) {
      _socket!.emit('location_update', {
        'sosId': sosId,
        'userId': _currentUserId,
        'latitude': lat,
        'longitude': lng,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  void emitSOSAlert(Map<String, dynamic> sosData) {
    if (_socket != null && _isConnected) {
      _socket!.emit('sos_alert', sosData);
    }
  }

  void disconnect() {
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
