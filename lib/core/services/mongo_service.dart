import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/identity_validator.dart';

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
      final dbName = (dotenv.env['MONGO_DB_NAME'] ?? 'sheild_ai_flutter').trim();
      
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
      await users.createIndex(keys: {'firebase_uid': 1}, unique: true, sparse: true);
      
      final locations = _db!.collection('user_locations');
      await locations.createIndex(keys: {'location': '2dsphere'});
      await locations.createIndex(keys: {'identifier': 1}, unique: true);
      await locations.createIndex(keys: {'phone': 1});

      final reports = _db!.collection('community_reports');
      await reports.createIndex(keys: {'location': '2dsphere'});
      await reports.createIndex(keys: {'reporter_phone': 1});
      
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
      debugPrint('[MongoService] Inserting into $collection: ${document.keys.toList()}');
      final result = await getCollection(collection).insertOne(document);
      if (result.isSuccess) {
        debugPrint('[MongoService] SUCCESS: Inserted into $collection.');
      } else {
        debugPrint('[MongoService] FAILED: Insert into $collection failed. Error: ${result.errmsg}');
      }
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
    
    if (identifier.contains('@')) {
      final byEmailCI = await findOne('users', where.match('email', '^' + RegExp.escape(identifier) + r'$', caseInsensitive: true));
      if (byEmailCI != null) return byEmailCI;
    }

    final byPhone = await findOne('users', where.eq('phone', identifier));
    if (byPhone != null) return byPhone;
    return await findOne('users', where.eq('firebase_uid', identifier));
  }

  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    return await findOne('users', where.eq('phone', phone));
  }

  Future<Map<String, dynamic>?> getUserByFirebaseUid(String uid) async {
    return await findOne('users', where.eq('firebase_uid', uid));
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
      await updateOne(
        'users', 
        where.eq('email', identifier)
             .or(where.eq('phone', identifier))
             .or(where.eq('firebase_uid', identifier)), 
        modifier, 
        upsert: true
      );
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

  Future<bool> createSOS(Map<String, dynamic> sosData) async {
    // Ensure GeoJSON location for better querying
    if (sosData.containsKey('latitude') && sosData.containsKey('longitude')) {
      final lat = (sosData['latitude'] as num).toDouble();
      final lon = (sosData['longitude'] as num).toDouble();
      sosData['location'] = {'type': 'Point', 'coordinates': [lon, lat]};
    }
    if (!sosData.containsKey('timestamp')) {
      sosData['timestamp'] = DateTime.now().toIso8601String();
    }
    return insertOne('sos_history', sosData);
  }

  Future<List<Map<String, dynamic>>> getUserSOSHistory(String phone) => find('sos_history', where.eq('user_phone', phone));

  Future<bool> updateSOSStatus(String sosId, String status) async {
    try {
      // Try by MongoDB ObjectId first
      if (sosId.length == 24) {
        final result = await updateOne('sos_history', where.eq('_id', ObjectId.parse(sosId)), modify.set('status', status));
        if (result) return true;
      }
      // Fallback to custom sos_id field
      return updateOne('sos_history', where.eq('sos_id', sosId), modify.set('status', status));
    } catch (e) {
      debugPrint('[MongoService] updateSOSStatus error: $e');
      return updateOne('sos_history', where.eq('id', sosId).or(where.eq('sos_id', sosId)), modify.set('status', status));
    }
  }

  Future<bool> addContact(String email, Map<String, dynamic> contactData) async {
    final rawUserPhone = contactData['user_phone'] as String? ?? '';
    final userPhone = IdentityValidator.isValidPhone(rawUserPhone) ? rawUserPhone : '';
    final userEmail = contactData['user_email'] as String? ?? email;
    
    final selector = userPhone.isNotEmpty
        ? where.eq('user_phone', userPhone).and(where.eq('phone', contactData['phone']))
        : where.eq('user_email', userEmail).and(where.eq('phone', contactData['phone']));
        
    var modifier = modify
        .set('name', contactData['name'])
        .set('relationship', contactData['relationship'] ?? 'Guardian')
        .set('phone', contactData['phone'])
        .set('user_email', userEmail)
        .set('user_phone', userPhone);

    return updateOne(
      'emergency_contacts',
      selector,
      modifier,
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

  Future<bool> deleteContactByPhone(String identifier, String phone) async {
    final col = getCollection('emergency_contacts');
    final selector = identifier.contains('@')
        ? where.eq('user_email', identifier).and(where.eq('phone', phone))
        : where.eq('user_phone', identifier).and(where.eq('phone', phone));
    final result = await col.deleteOne(selector);
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
      final latValue = reportData['latitude'] ?? reportData['lat'];
      final lonValue = reportData['longitude'] ?? reportData['lon'];
      
      if (latValue == null || lonValue == null) {
        debugPrint('[MongoService] Error: lat/lon missing in reportData');
        return false;
      }

      final lat = (latValue as num).toDouble();
      final lon = (lonValue as num).toDouble();
      
      // Ensure both are present for compatibility with all backends
      reportData['latitude'] = lat;
      reportData['longitude'] = lon;
      reportData['lat'] = lat;
      reportData['lon'] = lon;
      
      if (reportData.containsKey('phone')) {
        final phone = reportData['phone'] as String? ?? '';
        reportData['reporter_phone'] = IdentityValidator.isValidPhone(phone) ? phone : '';
      }
      
      reportData['location'] = {'type': 'Point', 'coordinates': [lon, lat]};
      reportData['timestamp'] = DateTime.now().toIso8601String();
      
      if (!reportData.containsKey('id')) {
        reportData['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      }
      
      debugPrint('[MongoService] Submitting report to community_reports collection');
      final success = await insertOne('community_reports', reportData);
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
