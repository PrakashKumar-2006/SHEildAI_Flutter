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

  Db? _dataDb;
  Db? _authDb;
  bool _dataConnected = false;
  bool _authConnected = false;
  int _connectionRetries = 0;
  static const int _maxRetries = 3;

  bool get isConnected => _dataConnected && _dataDb?.state == State.OPEN;
  bool get isAuthConnected => _authConnected && _authDb?.state == State.OPEN;
  
  Db? get database => _dataDb;
  Db? get authDatabase => _authDb;

  /// Connects to both Data and Auth databases.
  Future<void> connect() async {
    await Future.wait([
      _connectData(),
      _connectAuth(),
    ]);
  }

  Future<void> _connectData() async {
    if (_dataConnected && _dataDb?.state == State.OPEN) return;
    try {
      var uri = dotenv.env['MONGO_DB_DATA_CONNECTION_STRING']?.trim() ?? 
                dotenv.env['MONGO_DB_CONNECTION_STRING']?.trim() ?? '';
      _dataDb = await _establishConnection(uri, 'DATA');
      _dataConnected = true;
      await _ensureDataIndexes();
    } catch (e) {
      _dataConnected = false;
      debugPrint('[MongoService] DATA DB Connection Failed: $e');
    }
  }

  Future<void> _connectAuth() async {
    if (_authConnected && _authDb?.state == State.OPEN) return;
    try {
      var uri = dotenv.env['MONGO_DB_AUTH_CONNECTION_STRING']?.trim() ?? '';
      if (uri.isEmpty) {
        debugPrint('[MongoService] Auth DB string missing, using DATA DB as fallback for Auth.');
        _authDb = _dataDb;
        _authConnected = _dataConnected;
        return;
      }
      _authDb = await _establishConnection(uri, 'AUTH');
      _authConnected = true;
      await _ensureAuthIndexes();
    } catch (e) {
      _authConnected = false;
      debugPrint('[MongoService] AUTH DB Connection Failed: $e');
    }
  }

  Future<Db> _establishConnection(String uri, String label) async {
    if (uri.isEmpty) throw Exception('$label Connection string missing');
    
    // Add authSource=admin fix
    if (uri.startsWith('mongodb+srv') && !uri.contains('authSource=')) {
      final sep = uri.contains('?') ? '&' : '?';
      uri = '$uri${sep}authSource=admin';
    }

    // Ensure DB name is injected into URI (Atlas URIs often omit it)
    final dbName = dotenv.env['MONGO_DB_NAME']?.trim() ?? 'sheildai';
    if (!uri.contains('/$dbName')) {
      // Handle mongodb+srv://host/?query or mongodb+srv://host
      if (uri.contains('.net/')) {
        final netIndex = uri.indexOf('.net/') + 5;
        if (uri.length == netIndex || uri[netIndex] == '?') {
          uri = uri.replaceFirst('.net/', '.net/$dbName');
        }
      } else if (uri.contains('mongodb.net')) {
         // Fallback for URIs without trailing slash
         uri = uri.replaceFirst('mongodb.net', 'mongodb.net/$dbName');
      }
    }

    final masked = uri.replaceFirst(RegExp(r':.*@'), ':****@');
    debugPrint('[MongoService] Connecting to $label Atlas: $masked');
    
    try {
      final db = await Db.create(uri);
      await db.open();
      debugPrint('[MongoService] SUCCESS: $label Connected');
      return db;
    } catch (e) {
      debugPrint('[MongoService] FAILED: $label connection failed: $e');
      rethrow;
    }
  }

  Future<void> _ensureDataIndexes() async {
    try {
      final reports = _dataDb!.collection('community_reports');
      await reports.createIndex(keys: {'location': '2dsphere'}, name: 'location_2dsphere');
      
      final locations = _dataDb!.collection('user_locations');
      await locations.createIndex(keys: {'location': '2dsphere'}, name: 'user_location_2dsphere');
      await locations.createIndex(keys: {'identifier': 1}, unique: true);
      
      debugPrint('[MongoService] DATA Indexes verified.');
    } catch (e) {
      debugPrint('[MongoService] DATA Index verification failed: $e');
    }
  }

  Future<void> _ensureAuthIndexes() async {
    try {
      final users = _authDb!.collection('users');
      await users.createIndex(keys: {'email': 1}, unique: true);
      await users.createIndex(keys: {'phone': 1});

      final contacts = _authDb!.collection('emergency_contacts');
      await contacts.createIndex(keys: {'user_email': 1});
      
      debugPrint('[MongoService] AUTH Indexes verified.');
    } catch (e) {
      debugPrint('[MongoService] AUTH Index verification failed: $e');
    }
  }

  /// Higher-order function to wrap DB operations with auto-reconnect and tracing.
  Future<T> executeWithRetry<T>(Future<T> Function() operation, {bool useAuth = false}) async {
    int attempts = 0;
    while (attempts < _maxRetries) {
      try {
        if (useAuth) {
          if (!isAuthConnected) await _connectAuth();
        } else {
          if (!isConnected) await _connectData();
        }
        return await operation();
      } catch (e) {
        attempts++;
        final errorStr = e.toString();
        debugPrint('[MongoService] Op failed (${useAuth ? "AUTH" : "DATA"}, Attempt $attempts): $errorStr');
        
        if (errorStr.contains('No master connection') || errorStr.contains('Connection closed')) {
          if (useAuth) _authConnected = false; else _dataConnected = false;
        }

        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 1000 * attempts));
      }
    }
    throw Exception('Operation failed after retries');
  }

  DbCollection getCollection(String collectionName, {bool useAuth = false}) {
    final db = useAuth ? _authDb : _dataDb;
    if (db == null || db.state != State.OPEN) throw Exception('MongoDB ${useAuth ? "AUTH" : "DATA"} not connected');
    return db.collection(collectionName);
  }

  // ─── CRUD Operations ──────────────────────────────────────────────────────

  Future<bool> insertOne(String collection, Map<String, dynamic> document, {bool useAuth = false}) async {
    return executeWithRetry(() async {
      debugPrint('[MongoService] Inserting into $collection (${useAuth ? "AUTH" : "DATA"})');
      final result = await getCollection(collection, useAuth: useAuth).insertOne(document);
      return result.isSuccess;
    }, useAuth: useAuth);
  }

  Future<bool> updateOne(String collection, SelectorBuilder selector, ModifierBuilder update, {bool upsert = false, bool useAuth = false}) async {
    return executeWithRetry(() async {
      debugPrint('[MongoService] Updating $collection (${useAuth ? "AUTH" : "DATA"}, upsert: $upsert)');
      final result = await getCollection(collection, useAuth: useAuth).updateOne(selector, update, upsert: upsert);
      return result.isSuccess;
    }, useAuth: useAuth);
  }

  Future<Map<String, dynamic>?> findOne(String collection, SelectorBuilder selector, {bool useAuth = false}) async {
    return executeWithRetry(() async {
      return await getCollection(collection, useAuth: useAuth).findOne(selector);
    }, useAuth: useAuth);
  }

  Future<List<Map<String, dynamic>>> find(String collection, SelectorBuilder selector, {bool useAuth = false}) async {
    return executeWithRetry(() async {
      return await getCollection(collection, useAuth: useAuth).find(selector).toList();
    }, useAuth: useAuth);
  }

  // ─── Domain-Specific Methods ───────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserByEmail(String email) => findOne('users', where.eq('email', email), useAuth: true);
  Future<Map<String, dynamic>?> getUser(String email) => getUserByEmail(email);

  Future<bool> createUser(Map<String, dynamic> userData) => insertOne('users', userData, useAuth: true);

  Future<bool> updateUser(String email, Map<String, dynamic> updates) async {
    // 1. Update Profile in AUTH DB
    var authModifier = modify;
    bool hasProfileUpdates = false;
    
    // 2. Prepare Location update for DATA DB if present
    Map<String, dynamic>? locationPoint;
    
    for (var entry in updates.entries) {
      if (entry.key == 'location' && entry.value is Map && entry.value.containsKey('latitude')) {
        final lat = (entry.value['latitude'] as num).toDouble();
        final lon = (entry.value['longitude'] as num).toDouble();
        locationPoint = {
          'type': 'Point',
          'coordinates': [lon, lat]
        };
      } else {
        authModifier = authModifier.set(entry.key, entry.value);
        hasProfileUpdates = true;
      }
    }

    if (hasProfileUpdates) {
      await updateOne('users', where.eq('email', email), authModifier, upsert: true, useAuth: true);
    }

    // 3. Sync Location to DATA DB (for geospatial SOS alerts)
    if (locationPoint != null) {
      var dataModifier = modify
          .set('location', locationPoint)
          .set('lastSeen', DateTime.now().toIso8601String());
      
      // Also include name/phone for quick access during SOS alerts
      if (updates.containsKey('name')) dataModifier = dataModifier.set('name', updates['name']);
      if (updates.containsKey('phone')) dataModifier = dataModifier.set('phone', updates['phone']);

      await updateOne(
        'user_locations', 
        where.eq('identifier', email), 
        dataModifier,
        upsert: true,
        useAuth: false
      );
    }

    return true;
  }

  Future<List<Map<String, dynamic>>> getNearbyUsers(double lat, double lon, double radiusKm) async {
    return executeWithRetry(() async {
      debugPrint('[MongoService] Fetching nearby users from DATA DB within ${radiusKm}km');
      final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
      
      return await getCollection('user_locations', useAuth: false)
          .find(where
              .near('location', [lon, lat], radiusKm * 1000)
              .and(where.gt('lastSeen', twentyFourHoursAgo)))
          .toList();
    }, useAuth: false);
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
      useAuth: true,
    );
  }

  Future<List<Map<String, dynamic>>> getContacts(String identifier) => find('emergency_contacts', where.eq('user_email', identifier), useAuth: true);

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
      final byPhone = await find('emergency_contacts', where.eq('phone', phone), useAuth: true);
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
      return updateOne('emergency_contacts', where.eq('_id', ObjectId.parse(contactId)), modifier, useAuth: true);
    } catch (e) {
      return updateOne('emergency_contacts', where.eq('id', contactId), modifier, useAuth: true);
    }
  }

  Future<bool> deleteContact(String contactId) async {
    try {
      final col = getCollection('emergency_contacts', useAuth: true);
      final result = await col.deleteOne(where.eq('_id', ObjectId.parse(contactId)));
      return result.isSuccess;
    } catch (e) {
      final col = getCollection('emergency_contacts', useAuth: true);
      final result = await col.deleteOne(where.eq('id', contactId));
      return result.isSuccess;
    }
  }

  /// Delete a contact by matching user_email + phone number
  Future<bool> deleteContactByPhone(String userEmail, String phone) async {
    try {
      final col = getCollection('emergency_contacts', useAuth: true);
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

  Future<bool> createAlert(Map<String, dynamic> alertData) => insertOne('alerts', alertData, useAuth: false);

  Future<List<Map<String, dynamic>>> getAlerts(String email) => find('alerts', where.eq('user_email', email), useAuth: false);

  Future<bool> updateAlert(String alertId, Map<String, dynamic> updates) async {
    var modifier = modify;
    for (var entry in updates.entries) {
      modifier = modifier.set(entry.key, entry.value);
    }
    try {
      return updateOne('alerts', where.eq('_id', ObjectId.parse(alertId)), modifier, useAuth: false);
    } catch (e) {
      return updateOne('alerts', where.eq('id', alertId), modifier, useAuth: false);
    }
  }

  Future<bool> deleteAlert(String alertId) async {
    try {
      final col = getCollection('alerts', useAuth: false);
      final result = await col.deleteOne(where.eq('_id', ObjectId.parse(alertId)));
      return result.isSuccess;
    } catch (e) {
      final col = getCollection('alerts', useAuth: false);
      final result = await col.deleteOne(where.eq('id', alertId));
      return result.isSuccess;
    }
  }

  // ─── Community Methods ───────────────────────────────────────────────────

  Future<bool> submitCommunityReport(Map<String, dynamic> reportData) async {
    final lat = (reportData['lat'] ?? reportData['latitude'] as num).toDouble();
    final lon = (reportData['lon'] ?? reportData['longitude'] as num).toDouble();
    reportData['location'] = {'type': 'Point', 'coordinates': [lon, lat]};
    reportData['timestamp'] = DateTime.now().toIso8601String();
    return insertOne('community_reports', reportData);
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
    await _dataDb?.close();
    await _authDb?.close();
    _dataConnected = false;
    _authConnected = false;
  }
}
