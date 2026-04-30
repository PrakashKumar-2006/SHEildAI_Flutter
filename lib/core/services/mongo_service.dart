import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Centralized MongoDB Service for SHEildAI
/// Implements robust connection management, retry logic, and trace logging.
class MongoService {
  static final MongoService _instance = MongoService._internal();
  factory MongoService() => _instance;

  MongoService._internal();

  String? _connectionString;
  Db? _db;
  bool _isConnected = false;
  int _connectionRetries = 0;
  static const int _maxRetries = 3;

  bool get isConnected => _isConnected;
  Db? get database => _db;

  /// Connects to MongoDB Atlas with exponential backoff retry logic.
  Future<void> connect() async {
    if (_isConnected && _db != null && _db!.state == State.OPEN) return;

    try {
      _connectionString = dotenv.env['MONGO_DB_CONNECTION_STRING'];
      final dbName = dotenv.env['MONGO_DB_NAME'] ?? 'sheildai';
      
      if (_connectionString == null || _connectionString!.isEmpty) {
        throw Exception('MongoDB connection string missing in .env');
      }

      String finalUri = _connectionString!;
      if (finalUri.contains('.net/') && !finalUri.contains('.net/$dbName')) {
        finalUri = finalUri.replaceFirst('.net/', '.net/$dbName');
      }
      
      debugPrint('[MongoService] Connecting to Atlas (DB: $dbName)...');
      
      _db = await Db.create(finalUri);
      await _db!.open();
      
      _isConnected = true;
      _connectionRetries = 0;
      debugPrint('[MongoService] SUCCESS: Connected to Atlas DB: $dbName');
      
      await _ensureIndexes();
    } catch (e) {
      _isConnected = false;
      debugPrint('[MongoService] FAILED to connect: $e');
      if (_connectionRetries < _maxRetries) {
        _connectionRetries++;
        debugPrint('[MongoService] Retrying connection ($_connectionRetries/$_maxRetries)...');
        await Future.delayed(Duration(seconds: pow(2, _connectionRetries).toInt()));
        return connect();
      }
      rethrow;
    }
  }

  /// Ensures necessary indexes exist for performance and constraints.
  Future<void> _ensureIndexes() async {
    try {
      final reports = _db!.collection('community_reports');
      await reports.createIndex(keys: {'location': '2dsphere'});
      
      final users = _db!.collection('users');
      await users.createIndex(keys: {'email': 1}, unique: true);
      await users.createIndex(keys: {'phone': 1});

      final contacts = _db!.collection('emergency_contacts');
      await contacts.createIndex(keys: {'user_email': 1});
      
      debugPrint('[MongoService] DB Indexes verified.');
    } catch (e) {
      debugPrint('[MongoService] Index verification failed: $e');
    }
  }

  /// Helper to execute any DB operation with automatic reconnection and retry logic.
  Future<T> executeWithRetry<T>(Future<T> Function() operation, {String? traceId}) async {
    int attempts = 0;
    final id = traceId ?? _generateTraceId();
    
    while (attempts < _maxRetries) {
      try {
        await _ensureConnected();
        final result = await operation();
        debugPrint('[MongoService][$id] Operation SUCCESS');
        return result;
      } catch (e) {
        attempts++;
        debugPrint('[MongoService][$id] Operation FAILED (Attempt $attempts/$_maxRetries): $e');
        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    throw Exception('Operation failed after $_maxRetries retries');
  }

  Future<void> _ensureConnected() async {
    if (!_isConnected || _db == null || _db!.state != State.OPEN) {
      await connect();
    }
  }

  String _generateTraceId() => DateTime.now().millisecondsSinceEpoch.toString().substring(7);

  Future<void> disconnect() async {
    if (_db != null) {
      await _db!.close();
      _isConnected = false;
    }
  }

  DbCollection getCollection(String collectionName) {
    if (_db == null || !_isConnected) throw Exception('MongoDB not connected');
    return _db!.collection(collectionName);
  }

  // Generic CRUD wrappers with trace IDs and write acknowledgment

  Future<WriteResult> insertOne(String collection, Map<String, dynamic> document, {String? traceId}) {
    return executeWithRetry(() async {
      final col = getCollection(collection);
      return await col.insertOne(document);
    }, traceId: traceId);
  }

  Future<WriteResult> updateOne(String collection, SelectorBuilder selector, ModifierBuilder update, {bool upsert = false, String? traceId}) {
    return executeWithRetry(() async {
      final col = getCollection(collection);
      return await col.updateOne(selector, update, upsert: upsert);
    }, traceId: traceId);
  }

  Future<WriteResult> deleteOne(String collection, SelectorBuilder selector, {String? traceId}) {
    return executeWithRetry(() async {
      final col = getCollection(collection);
      return await col.deleteOne(selector);
    }, traceId: traceId);
  }

  Future<Map<String, dynamic>?> findOne(String collection, SelectorBuilder selector) {
    return executeWithRetry(() async {
      final col = getCollection(collection);
      return await col.findOne(selector);
    });
  }

  Future<List<Map<String, dynamic>>> find(String collection, SelectorBuilder selector) {
    return executeWithRetry(() async {
      final col = getCollection(collection);
      return await col.find(selector).toList();
    });
  }

  // High-level Domain Operations (Refactored to use generic wrappers)

  Future<Map<String, dynamic>?> getUserByEmail(String email) => findOne('users', where.eq('email', email));
  Future<Map<String, dynamic>?> getUser(String email) => getUserByEmail(email);

  Future<bool> createUser(Map<String, dynamic> userData) async {
    final result = await insertOne('users', userData);
    return result.isSuccess;
  }

  Future<bool> updateUser(String email, Map<String, dynamic> updates) async {
    var modifier = modify;
    for (var entry in updates.entries) {
      modifier = modifier.set(entry.key, entry.value);
    }
    final result = await updateOne('users', where.eq('email', email), modifier);
    return result.isSuccess;
  }

  Future<bool> createSOS(Map<String, dynamic> sosData) async {
    final result = await insertOne('sos_history', sosData);
    return result.isSuccess;
  }

  Future<List<Map<String, dynamic>>> getUserSOSHistory(String phone) => find('sos_history', where.eq('user_phone', phone));

  Future<bool> updateSOSStatus(String sosId, String status) async {
    final result = await updateOne('sos_history', where.eq('_id', ObjectId.parse(sosId)), modify.set('status', status));
    return result.isSuccess;
  }

  Future<bool> addContact(String email, Map<String, dynamic> contactData) async {
    final result = await updateOne(
      'emergency_contacts',
      where.eq('user_email', email).and(where.eq('phone', contactData['phone'])),
      modify.set('name', contactData['name'])
            .set('relationship', contactData['relationship'] ?? 'Guardian')
            .set('user_email', email),
      upsert: true,
    );
    return result.isSuccess;
  }

  Future<List<Map<String, dynamic>>> getContactsByEmail(String email) => find('emergency_contacts', where.eq('user_email', email));
  Future<List<Map<String, dynamic>>> getContacts(String identifier) => getContactsByEmail(identifier);

  Future<bool> deleteContact(String contactId) async {
    final result = await deleteOne('emergency_contacts', where.eq('_id', ObjectId.parse(contactId)));
    return result.isSuccess;
  }

  Future<bool> updateContact(String contactId, Map<String, dynamic> updates) async {
    var modifier = modify;
    for (var entry in updates.entries) {
      modifier = modifier.set(entry.key, entry.value);
    }
    final result = await updateOne('emergency_contacts', where.eq('_id', ObjectId.parse(contactId)), modifier);
    return result.isSuccess;
  }

  Future<bool> createAlert(Map<String, dynamic> alertData) async {
    final result = await insertOne('alerts', alertData);
    return result.isSuccess;
  }

  Future<List<Map<String, dynamic>>> getAlerts(String email) => find('alerts', where.eq('user_email', email));

  Future<bool> deleteAlert(String alertId) async {
    final result = await deleteOne('alerts', where.eq('_id', ObjectId.parse(alertId)));
    return result.isSuccess;
  }

  Future<bool> updateAlert(String alertId, Map<String, dynamic> updates) async {
    var modifier = modify;
    for (var entry in updates.entries) {
      modifier = modifier.set(entry.key, entry.value);
    }
    final result = await updateOne('alerts', where.eq('_id', ObjectId.parse(alertId)), modifier);
    return result.isSuccess;
  }

  Future<bool> submitCommunityReport(Map<String, dynamic> reportData) async {
    final lat = (reportData['lat'] ?? reportData['latitude'] as num).toDouble();
    final lon = (reportData['lon'] ?? reportData['longitude'] as num).toDouble();
    
    reportData['timestamp'] = DateTime.now().toIso8601String();
    reportData['location'] = {'type': 'Point', 'coordinates': [lon, lat]};
    
    final result = await insertOne('community_reports', reportData);
    return result.isSuccess;
  }

  Future<List<Map<String, dynamic>>> getNearbyReports(double lat, double lon, double radiusKm) async {
    try {
      return await find('community_reports', where.near('location', [lon, lat], radiusKm * 1000));
    } catch (e) {
      debugPrint('[MongoService] Geo-query failed, using fallback filter');
      final all = await find('community_reports', where.sortBy('created_at', descending: true).limit(100));
      return all.where((rpt) {
        final rlat = (rpt['lat'] ?? rpt['latitude'] as num).toDouble();
        final rlon = (rpt['lon'] ?? rpt['longitude'] as num).toDouble();
        return _calculateDistance(lat, lon, rlat, rlon) <= radiusKm;
      }).toList();
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371.0;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) + cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRadians(double degree) => degree * (3.141592653589793 / 180.0);

  Future<bool> saveLocationLog(Map<String, dynamic> locationData) async {
    final result = await insertOne('location_logs', locationData);
    return result.isSuccess;
  }

  Future<bool> createSubscription(Map<String, dynamic> subscriptionData) async {
    final result = await insertOne('subscriptions', subscriptionData);
    return result.isSuccess;
  }

  Future<Map<String, dynamic>?> getActiveSubscription(String phone) {
    return findOne('subscriptions', 
      where.eq('user_phone', phone)
           .eq('isActive', true)
           .gt('endDate', DateTime.now().toIso8601String()));
  }
}
