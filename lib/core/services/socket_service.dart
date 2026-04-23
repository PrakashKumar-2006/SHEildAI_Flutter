import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  SocketService._internal();

  static const String _backendUrl = 'wss://sheildai1-o.onrender.com';
  
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  bool _isConnected = false;
  String? _currentUserId;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(String phone) async {
    try {
      _currentUserId = phone;
      _channel = WebSocketChannel.connect(Uri.parse('$_backendUrl/socket.io/?phone=$phone'));
      
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          _isConnected = false;
          _connectionController.add(false);
        },
        onDone: () {
          _isConnected = false;
          _connectionController.add(false);
        },
      );
      
      _isConnected = true;
      _connectionController.add(true);
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
    }
  }

  void _handleMessage(dynamic message) {
    try {
      if (message is String) {
        final data = message;
        _messageController.add({'type': 'message', 'data': data});
      }
    } catch (e) {
      // Ignore parse errors
    }
  }

  void joinSOSRoom(String sosId) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add({
        'event': 'join_sos',
        'sosId': sosId,
        'userId': _currentUserId,
      }.toString());
    }
  }

  void emitLiveLocationUpdate(String sosId, double lat, double lng) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add({
        'event': 'location_update',
        'sosId': sosId,
        'userId': _currentUserId,
        'latitude': lat,
        'longitude': lng,
        'timestamp': DateTime.now().toIso8601String(),
      }.toString());
    }
  }

  void emitSOSAlert(Map<String, dynamic> sosData) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add({
        'event': 'sos_alert',
        'data': sosData,
      }.toString());
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
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
