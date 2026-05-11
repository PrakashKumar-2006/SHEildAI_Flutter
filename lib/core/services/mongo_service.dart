import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MongoService {
  Db? _db;
  bool _isConnected = false;
  final int _maxRetries = 3;

  static final MongoService _instance = MongoService._internal();
  factory MongoService() => _instance;
  MongoService._internal();

  bool get isConnected => _isConnected && _db != null && _db!.state == State.OPEN;
  
  // Backward compatibility getters
  bool get isAuthConnected => isConnected;
  bool get isDataConnected => isConnected;

  Future<void> connect() async {
    if (isConnected) return;

    try {
      var connectionString = (dotenv.env['MONGO_DB_CONNECTION_STRING'] ?? dotenv.env['MONGO_URI'] ?? '').trim();
      final dbName = (dotenv.env['MONGO_DB_NAME'] ?? 'sheildai').trim();
      
      if (connectionString.isEmpty) {
        throw Exception('MongoDB connection string missing in .env (check MONGO_DB_CONNECTION_STRING or MONGO_URI)');
      }

      String finalUri = connectionString;
      
      if (!finalUri.contains('/$dbName')) {
        // Find the spot to inject the DB name (before '?' or at the end)
        if (finalUri.contains('?')) {
          finalUri = finalUri.replaceFirst('?', '$dbName?');
        } else {
          finalUri = finalUri.endsWith('/') ? '$finalUri$dbName' : '$finalUri/$dbName';
        }
      }

      // Atlas requirement: Ensure authSource=admin
      if (finalUri.startsWith('mongodb') && !finalUri.contains('authSource')) {
        finalUri += finalUri.contains('?') ? '&authSource=admin' : '?authSource=admin';
      }

      final logUri = finalUri.replaceFirst(RegExp(r':([^@]+)@'), ':****@');
      debugPrint('[MongoService] Connecting with URI: $logUri');
      
      if (_db != null) {
        try { await _db!.close(); } catch (_) {}
      }

      _db = await Db.create(finalUri);
      await _db!.open().timeout(const Duration(seconds: 15));
      await _db!.getBuildInfo();

      _isConnected = true;
      
      await _ensureIndexes();
      debugPrint('[MongoService] SUCCESS: Unified Database Connected (${_db!.databaseName})');
    } catch (e) {
      _isConnected = false;
      debugPrint('[MongoService] FAILED: Connection error: $e');
      rethrow;
    }
  }

  Future<void> _ensureIndexes() async {
    try {
      final users = _db!.collection('users');
      await users.createIndex(keys: {'email': 1}, unique: true, sparse: true);
      await users.createIndex(keys: {'phone': 1}, unique: true);
      
      final locations = _db!.collection('user_locations');
      await locations.createIndex(keys: {'location': '2dsphere'});
      await locations.createIndex(keys: {'identifier': 1}, unique: true);
      await locations.createIndex(keys: {'phone': 1});

      final reports = _db!.collection('community_reports');
      await reports.createIndex(keys: {'location': '2dsphere'});
      
      final contacts = _db!.collection('emergency_contacts');
      await contacts.createIndex(keys: {'user_email': 1});
      await contacts.createIndex(keys: {'user_phone': 1});

      debugPrint('[MongoService] All indexes verified.');
    } catch (e) {
      debugPrint('[MongoService] Index verification failed: $e');
    }
  }

  Future<T> executeWithRetry<T>(Future<T> Function() operation, {bool useAuth = false}) async {
    int attempts = 0;
    while (attempts < _maxRetries) {
      try {
        if (!isConnected) await connect();
        return await operation();
      } catch (e) {
        attempts++;
        final errorStr = e.toString();
        debugPrint('[MongoService] Op failed (Attempt $attempts): $errorStr');
        
        if (errorStr.contains('No master connection') || errorStr.contains('Connection closed')) {
          _isConnected = false;
        }

        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 1000 * attempts));
      }
    }
    throw Exception('Operation failed after retries');
  }

  DbCollection getCollection(String collectionName, {bool useAuth = false}) {
    if (!isConnected) throw Exception('Database not connected');
    return _db!.collection(collectionName);
  }

  // ─── CRUD Operations ──────────────────────────────────────────────────────

  Future<bool> insertOne(String collection, Map<String, dynamic> document, {bool useAuth = false}) async {
    return executeWithRetry(() async {
      final result = await getCollection(collection).insertOne(document);
      return result.isSuccess;
    });
  }

  Future<bool> updateOne(String collection, SelectorBuilder selector, ModifierBuilder update, {bool upsert = false, bool useAuth = false}) async {
    return executeWithRetry(() async {
      final result = await getCollection(collection).updateOne(selector, update, upsert: upsert);
      return result.isSuccess;
    });
  }

  Future<Map<String, dynamic>?> findOne(String collection, SelectorBuilder selector, {bool useAuth = false}) async {
    return executeWithRetry(() async {
      return await getCollection(collection).findOne(selector);
    });
  }

  Future<List<Map<String, dynamic>>> find(String collection, SelectorBuilder selector, {bool useAuth = false}) async {
    return executeWithRetry(() async {
      return await getCollection(collection).find(selector).toList();
    });
  }

  // ─── Domain-Specific Methods ───────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserByEmail(String identifier) async {
    final byEmail = await findOne('users', where.eq('email', identifier));
    if (byEmail != null) return byEmail;
    return await findOne('users', where.eq('phone', identifier));
  }

  Future<Map<String, dynamic>?> getUser(String identifier) => getUserByEmail(identifier);

  Future<bool> createUser(Map<String, dynamic> userData) async {
    return insertOne('users', userData);
  }

  Future<bool> updateUser(String identifier, Map<String, dynamic> updates) async {
    var modifier = modify;
    bool hasProfileUpdates = false;
    Map<String, dynamic>? locationPoint;
    
    for (var entry in updates.entries) {
      if (entry.key == 'location' && entry.value is Map && entry.value.containsKey('latitude')) {
        final lat = (entry.value['latitude'] as num).toDouble();
        final lon = (entry.value['longitude'] as num).toDouble();
        locationPoint = {'type': 'Point', 'coordinates': [lon, lat]};
      } else {
        modifier = modifier.set(entry.key, entry.value);
        hasProfileUpdates = true;
      }
    }

    if (hasProfileUpdates) {
      await updateOne('users', where.eq('email', identifier).or(where.eq('phone', identifier)), modifier, upsert: true);
    }

    if (locationPoint != null) {
      var locModifier = modify
          .set('location', locationPoint)
          .set('lastSeen', DateTime.now().toIso8601String())
          .set('identifier', identifier);
      
      if (updates.containsKey('name')) locModifier = locModifier.set('name', updates['name']);
      if (updates.containsKey('phone')) locModifier = locModifier.set('phone', updates['phone']);
      if (updates.containsKey('email')) locModifier = locModifier.set('email', updates['email']);

      await updateOne('user_locations', where.eq('identifier', identifier), locModifier, upsert: true);
    }
    return true;
  }

  Future<List<Map<String, dynamic>>> getNearbyUsers(double lat, double lon, double radiusKm) async {
    return executeWithRetry(() async {
      final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
      final selector = {
        'location': {
          '\$nearSphere': {
            '\$geometry': {'type': 'Point', 'coordinates': [lon, lat]},
            '\$maxDistance': radiusKm * 1000
          }
        },
        'lastSeen': {'\$gt': twentyFourHoursAgo}
      };
      return await find('user_locations', where.raw(selector));
    });
  }

  // ─── SOS & Community Methods ──────────────────────────────────────────────

  Future<bool> createSOS(Map<String, dynamic> sosData) => insertOne('sos_history', sosData);

  Future<List<Map<String, dynamic>>> getUserSOSHistory(String phone) => find('sos_history', where.eq('user_phone', phone));

  Future<bool> updateSOSStatus(String sosId, String status) async {
    try {
      return await updateOne('sos_history', where.eq('_id', ObjectId.parse(sosId)), modify.set('status', status));
    } catch (e) {
      return updateOne('sos_history', where.eq('id', sosId), modify.set('status', status));
    }
  }

  Future<bool> addContact(String email, Map<String, dynamic> contactData) async {
    return updateOne(
      'emergency_contacts',
      where.eq('user_email', email).and(where.eq('phone', contactData['phone'])),
      modify.set('name', contactData['name'])
            .set('relationship', contactData['relationship'] ?? 'Guardian')
            .set('user_email', email)
            .set('user_phone', contactData['user_phone'] ?? ''),
      upsert: true,
    );
  }

  Future<List<Map<String, dynamic>>> getContacts(String identifier) => find('emergency_contacts', where.eq('user_email', identifier).or(where.eq('user_phone', identifier)));

  // Backward compatibility methods for Contacts
  Future<List<Map<String, dynamic>>> getContactsForUser({String? email, String? phone}) {
    return find('emergency_contacts', where.eq('user_email', email).or(where.eq('user_phone', phone)));
  }

  Future<List<Map<String, dynamic>>> getContactsByEmail(String email) => getContacts(email);

  Future<bool> updateContact(String contactId, Map<String, dynamic> updates) async {
    var modifier = modify;
    for (var entry in updates.entries) {
      modifier = modifier.set(entry.key, entry.value);
    }
    try {
      return updateOne('emergency_contacts', where.eq('_id', ObjectId.parse(contactId)), modifier);
    } catch (e) {
      return updateOne('emergency_contacts', where.eq('id', contactId), modifier);
    }
  }

  Future<bool> deleteContact(String contactId) async {
    try {
      final col = getCollection('emergency_contacts');
      final result = await col.deleteOne(where.eq('_id', ObjectId.parse(contactId)));
      return result.isSuccess;
    } catch (e) {
      final col = getCollection('emergency_contacts');
      final result = await col.deleteOne(where.eq('id', contactId));
      return result.isSuccess;
    }
  }

  Future<bool> deleteContactByPhone(String userEmail, String phone) async {
    final col = getCollection('emergency_contacts');
    final result = await col.deleteOne(where.eq('user_email', userEmail).and(where.eq('phone', phone)));
    return result.isSuccess;
  }

  // Backward compatibility methods for Alerts
  Future<bool> createAlert(Map<String, dynamic> alertData) => insertOne('alerts', alertData);
  
  Future<List<Map<String, dynamic>>> getAlerts(String email) => find('alerts', where.eq('user_email', email));

  Future<bool> updateAlert(String alertId, Map<String, dynamic> updates) async {
    var modifier = modify;
    for (var entry in updates.entries) {
      modifier = modifier.set(entry.key, entry.value);
    }
    try {
      return updateOne('alerts', where.eq('_id', ObjectId.parse(alertId)), modifier);
    } catch (e) {
      return updateOne('alerts', where.eq('id', alertId), modifier);
    }
  }

  Future<bool> deleteAlert(String alertId) async {
    try {
      final col = getCollection('alerts');
      final result = await col.deleteOne(where.eq('_id', ObjectId.parse(alertId)));
      return result.isSuccess;
    } catch (e) {
      final col = getCollection('alerts');
      final result = await col.deleteOne(where.eq('id', alertId));
      return result.isSuccess;
    }
  }

  // ─── Community Methods ───────────────────────────────────────────────────

  Future<bool> submitCommunityReport(Map<String, dynamic> reportData) async {
    try {
      final latValue = reportData['lat'] ?? reportData['latitude'];
      final lonValue = reportData['lon'] ?? reportData['longitude'];
      
      if (latValue == null || lonValue == null) {
        debugPrint('[MongoService] Error: lat/lon missing in reportData');
        return false;
      }

      final lat = (latValue as num).toDouble();
      final lon = (lonValue as num).toDouble();
      
      reportData['location'] = {'type': 'Point', 'coordinates': [lon, lat]};
      reportData['timestamp'] = DateTime.now().toIso8601String();
      
      debugPrint('[MongoService] Submitting report to community_reports collection');
      final success = await insertOne('community_reports', reportData);
      if (success) {
        debugPrint('[MongoService] SUCCESS: Report stored in database.');
      } else {
        debugPrint('[MongoService] FAILED: insertOne returned false for community_report.');
      }
      return success;
    } catch (e) {
      debugPrint('[MongoService] submitCommunityReport exception: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyReports(double lat, double lon, double radiusKm) async {
    try {
      final selector = {
        'location': {
          '\$nearSphere': {
            '\$geometry': {'type': 'Point', 'coordinates': [lon, lat]},
            '\$maxDistance': radiusKm * 1000
          }
        }
      };
      return await find('community_reports', where.raw(selector));
    } catch (e) {
      return find('community_reports', where.sortBy('timestamp', descending: true).limit(50));
    }
  }

  Future<void> disconnect() async {
    await _db?.close();
    _isConnected = false;
  }
}
