import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mongo_dart/mongo_dart.dart';

/// Centralized MongoDB Service for SHEildAI
/// Handles connection management, robust error recovery, and CRUD operations.
class MongoService {
  static final MongoService _instance = MongoService._internal();
  factory MongoService() => _instance;

  MongoService._internal();

  Db? _db;
  bool _isConnected = false;
  int _connectionRetries = 0;
  static const int _maxRetries = 3;

  bool get isConnected => _isConnected && _db != null && _db!.state == State.OPEN;
  Db? get database => _db;

  /// Connects to MongoDB Atlas with robust state management.
  Future<void> connect() async {
    if (isConnected) return;

    // Avoid concurrent connection attempts
    if (_db != null && _db!.state == State.OPENING) {
      debugPrint('[MongoService] Connection already in progress, waiting...');
      return; 
    }

    try {
      var connectionString = dotenv.env['MONGO_DB_CONNECTION_STRING']?.trim() ?? '';
      final dbName = (dotenv.env['MONGO_DB_NAME'] ?? 'sheildai').trim();
      
      if (connectionString.isEmpty) {
        throw Exception('MongoDB connection string missing in .env');
      }

      // If the string already contains the DB name and parameters, use it as is
      // Otherwise, we need to inject the DB name correctly.
      String finalUri = connectionString;
      
      if (!finalUri.contains('/$dbName')) {
        // Find the spot to inject the DB name (before '?' or at the end)
        if (finalUri.contains('?')) {
          finalUri = finalUri.replaceFirst('?', '$dbName?');
        } else {
          finalUri = finalUri.endsWith('/') ? '$finalUri$dbName' : '$finalUri/$dbName';
        }
      }

      // Atlas/mongo_dart Fix: Ensure authSource=admin for Atlas srv connections
      if (finalUri.startsWith('mongodb+srv') && !finalUri.contains('authSource')) {
        finalUri += finalUri.contains('?') ? '&authSource=admin' : '?authSource=admin';
      }

      // Sanitize for logging (mask password)
      final logUri = finalUri.replaceFirst(RegExp(r':([^@]+)@'), ':****@');
      debugPrint('[MongoService] Connecting with URI: $logUri');
      
      // Close old instance if it exists
      if (_db != null) {
        try { await _db!.close(); } catch (_) {}
      }

      _db = await Db.create(finalUri);
      await _db!.open().timeout(const Duration(seconds: 15));
      
      // Verify connection with a light command
      await _db!.getBuildInfo();
      
      _isConnected = true;
      _connectionRetries = 0;
      debugPrint('[MongoService] SUCCESS: Connected to Atlas DB: $dbName');
      
      await _ensureIndexes();
    } catch (e) {
      _isConnected = false;
      debugPrint('[MongoService] FAILED to connect: $e');
      if (_connectionRetries < _maxRetries) {
        _connectionRetries++;
        debugPrint('[MongoService] Retrying ($_connectionRetries/$_maxRetries)...');
        await Future.delayed(Duration(seconds: pow(2, _connectionRetries).toInt()));
        return connect();
      }
      rethrow;
    }
  }

  /// Ensures indexes for performance and geo-spatial queries.
  Future<void> _ensureIndexes() async {
    try {
      final reports = _db!.collection('community_reports');
      await reports.createIndex(keys: {'location': '2dsphere'}, name: 'location_2dsphere');
      
      final users = _db!.collection('users');
      await users.createIndex(keys: {'email': 1}, unique: true);
      await users.createIndex(keys: {'phone': 1});

      final contacts = _db!.collection('emergency_contacts');
      await contacts.createIndex(keys: {'user_email': 1});
      
      debugPrint('[MongoService] Indexes verified.');
    } catch (e) {
      debugPrint('[MongoService] Index verification failed (likely already exists): $e');
    }
  }

  /// Higher-order function to wrap DB operations with auto-reconnect and tracing.
  Future<T> executeWithRetry<T>(Future<T> Function() operation) async {
    int attempts = 0;
    while (attempts < _maxRetries) {
      try {
        if (!isConnected) await connect();
        return await operation();
      } catch (e) {
        attempts++;
        final errorStr = e.toString();
        debugPrint('[MongoService] Op failed (Attempt $attempts): $errorStr');
        
        // If connection is lost or broken, reset state to force reconnect
        if (errorStr.contains('No master connection') || 
            errorStr.contains('Connection closed') ||
            errorStr.contains('Connection reset')) {
          _isConnected = false;
        }

        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 1000 * attempts));
      }
    }
    throw Exception('Operation failed after retries');
  }

  DbCollection getCollection(String collectionName) {
    if (!isConnected) throw Exception('MongoDB not connected');
    return _db!.collection(collectionName);
  }

  // ─── CRUD Operations ──────────────────────────────────────────────────────

  Future<bool> insertOne(String collection, Map<String, dynamic> document) async {
    return executeWithRetry(() async {
      debugPrint('[MongoService] Inserting into $collection');
      final result = await getCollection(collection).insertOne(document);
      return result.isSuccess;
    });
  }

  Future<bool> updateOne(String collection, SelectorBuilder selector, ModifierBuilder update, {bool upsert = false}) async {
    return executeWithRetry(() async {
      debugPrint('[MongoService] Updating $collection (upsert: $upsert)');
      final result = await getCollection(collection).updateOne(selector, update, upsert: upsert);
      return result.isSuccess;
    });
  }

  Future<Map<String, dynamic>?> findOne(String collection, SelectorBuilder selector) async {
    return executeWithRetry(() async {
      return await getCollection(collection).findOne(selector);
    });
  }

  Future<List<Map<String, dynamic>>> find(String collection, SelectorBuilder selector) async {
    return executeWithRetry(() async {
      return await getCollection(collection).find(selector).toList();
    });
  }

  // ─── Domain-Specific Methods ───────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserByEmail(String email) => findOne('users', where.eq('email', email));
  Future<Map<String, dynamic>?> getUser(String email) => getUserByEmail(email);

  Future<bool> createUser(Map<String, dynamic> userData) => insertOne('users', userData);

  Future<bool> updateUser(String email, Map<String, dynamic> updates) async {
    var modifier = modify;
    for (var entry in updates.entries) {
      modifier = modifier.set(entry.key, entry.value);
    }
    return updateOne('users', where.eq('email', email), modifier, upsert: true);
  }

  // ─── SOS Methods ─────────────────────────────────────────────────────────

  Future<bool> createSOS(Map<String, dynamic> sosData) => insertOne('sos_history', sosData);

  Future<List<Map<String, dynamic>>> getUserSOSHistory(String phone) => find('sos_history', where.eq('user_phone', phone));

  Future<bool> updateSOSStatus(String sosId, String status) async {
    try {
      final result = await updateOne('sos_history', where.eq('_id', ObjectId.parse(sosId)), modify.set('status', status));
      return result;
    } catch (e) {
      // Fallback if ID is not a valid ObjectId (legacy)
      return updateOne('sos_history', where.eq('id', sosId), modify.set('status', status));
    }
  }

  // ─── Contact Methods ─────────────────────────────────────────────────────

  Future<bool> addContact(String email, Map<String, dynamic> contactData) async {
    return updateOne(
      'emergency_contacts',
      where.eq('user_email', email).and(where.eq('phone', contactData['phone'])),
      modify.set('name', contactData['name'])
            .set('relationship', contactData['relationship'] ?? 'Guardian')
            .set('user_email', email),
      upsert: true,
    );
  }

  Future<List<Map<String, dynamic>>> getContacts(String identifier) => find('emergency_contacts', where.eq('user_email', identifier));

  Future<List<Map<String, dynamic>>> getContactsForUser({String? email, String? phone}) async {
    List<Map<String, dynamic>> allContacts = [];
    Set<String> seenIds = {};

    if (email != null && email.isNotEmpty) {
      final byEmail = await getContacts(email);
      for (var c in byEmail) {
        final id = c['_id']?.toString() ?? c['id']?.toString();
        if (id != null && !seenIds.contains(id)) {
          allContacts.add(c);
          seenIds.add(id);
        }
      }
    }

    if (phone != null && phone.isNotEmpty) {
      final byPhone = await getContacts(phone);
      for (var c in byPhone) {
        final id = c['_id']?.toString() ?? c['id']?.toString();
        if (id != null && !seenIds.contains(id)) {
          allContacts.add(c);
          seenIds.add(id);
        }
      }
    }
    return allContacts;
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

  /// Delete a contact by matching user_email + phone number
  Future<bool> deleteContactByPhone(String userEmail, String phone) async {
    try {
      final col = getCollection('emergency_contacts');
      final result = await col.deleteOne(
        where.eq('user_email', userEmail).and(where.eq('phone', phone)),
      );
      debugPrint('[MongoService] deleteContactByPhone($userEmail, $phone): ${result.isSuccess}');
      return result.isSuccess;
    } catch (e) {
      debugPrint('[MongoService] deleteContactByPhone error: $e');
      return false;
    }
  }



  // ─── Alert Methods ───────────────────────────────────────────────────────

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
      return await insertOne('community_reports', reportData);
    } catch (e) {
      debugPrint('[MongoService] submitCommunityReport exception: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyReports(double lat, double lon, double radiusKm) async {
    try {
      return await find('community_reports', where.near('location', [lon, lat], radiusKm * 1000));
    } catch (e) {
      debugPrint('[MongoService] Geo-query fallback triggered');
      return find('community_reports', where.sortBy('timestamp', descending: true).limit(50));
    }
  }

  Future<void> disconnect() async {
    await _db?.close();
    _isConnected = false;
  }
}
