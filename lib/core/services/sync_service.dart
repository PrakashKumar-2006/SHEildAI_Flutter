import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  SyncService._internal();

  static const String _syncQueueBox = 'sync_queue';
  bool _isOnline = true;
  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  Timer? _syncTimer;

  Stream<bool> get connectivityStream => _connectivityController.stream;
  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    await Hive.openBox(_syncQueueBox);
    
    // Check initial connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    _isOnline = _isConnected(connectivityResult);
    
    // Listen to connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = _isConnected(result);
      
      if (!wasOnline && _isOnline) {
        // Came back online - start syncing
        _startSync();
      }
      
      _connectivityController.add(_isOnline);
    });
  }

  bool _isConnected(ConnectivityResult result) {
    return result != ConnectivityResult.none;
  }

  Future<void> addToQueue(Map<String, dynamic> action) async {
    final box = Hive.box(_syncQueueBox);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final queuedAction = {
      'id': timestamp,
      'timestamp': DateTime.now().toIso8601String(),
      'action': action,
      'synced': false,
    };
    await box.put(timestamp, queuedAction);
  }

  Future<List<Map<String, dynamic>>> getPendingActions() async {
    final box = Hive.box(_syncQueueBox);
    final actions = box.values.toList().cast<Map<String, dynamic>>();
    return actions.where((action) => action['synced'] == false).toList();
  }

  Future<void> markAsSynced(String actionId) async {
    final box = Hive.box(_syncQueueBox);
    final action = box.get(actionId);
    if (action != null) {
      action['synced'] = true;
      await box.put(actionId, action);
    }
  }

  Future<void> removeSyncedActions() async {
    final box = Hive.box(_syncQueueBox);
    final keys = box.keys.toList();
    for (final key in keys) {
      final action = box.get(key);
      if (action != null && action['synced'] == true) {
        await box.delete(key);
      }
    }
  }

  void _startSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final pendingActions = await getPendingActions();
      if (pendingActions.isEmpty) {
        timer.cancel();
        await removeSyncedActions();
      } else {
        // Process pending actions
        for (final action in pendingActions) {
          await _processAction(action);
        }
      }
    });
  }

  Future<void> _processAction(Map<String, dynamic> action) async {
    // Process the action based on its type
    // This would typically involve API calls to sync with server
    // For now, we'll mark it as synced
    await markAsSynced(action['id'] as String);
  }

  Future<void> clearQueue() async {
    final box = Hive.box(_syncQueueBox);
    await box.clear();
  }

  void dispose() {
    _syncTimer?.cancel();
    _connectivityController.close();
  }
}
