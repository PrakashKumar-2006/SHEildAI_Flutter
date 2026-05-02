import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/constants/app_constants.dart';

class MongoService {
  Db? _db;
  bool _isConnected = false;
  final int _maxRetries = 3;

  static final MongoService _instance = MongoService._internal();
  factory MongoService() => _instance;
  MongoService._internal();

  bool get isConnected => _isConnected && _db != null && _db!.state == State.OPEN;

  Future<void> connect() async {
    if (isConnected) return;

    try {
      final uri = dotenv.env['MONGO_URI'] ?? '';
      if (uri.isEmpty) throw Exception('MONGO_URI is empty in .env');

      final masked = uri.replaceFirst(RegExp(r':.*@'), ':****@');
      debugPrint('[MongoService] Connecting to Unified Atlas: $masked');

      _db = await Db.create(uri);
      await _db!.open();
      _isConnected = true;
      
      await _ensureIndexes();
      debugPrint('[MongoService] SUCCESS: Unified Database Connected');
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
        
        if (errorStr.contains('No master connection') || errorStr.contains('Connection closed')) {
          _isConnected = false;
        }

        if (attempts >= _maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 1000 * attempts));
      }
    }
    throw Exception('Operation failed after retries');
  }

  DbCollection getCollection(String collectionName) {
    if (!isConnected) throw Exception('Database not connected');
    return _db!.collection(collectionName);
  }

  // ─── CRUD Operations ──────────────────────────────────────────────────────

  Future<bool> insertOne(String collection, Map<String, dynamic> document) async {
    return executeWithRetry(() async {
      final result = await getCollection(collection).insertOne(document);
      return result.isSuccess;
    });
  }

  Future<bool> updateOne(String collection, SelectorBuilder selector, ModifierBuilder update, {bool upsert = false}) async {
    return executeWithRetry(() async {
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

  Future<Map<String, dynamic>?> getUserByEmail(String identifier) async {
    // Try email first
    final byEmail = await findOne('users', where.eq('email', identifier));
    if (byEmail != null) return byEmail;
    
    // Try phone second
    return await findOne('users', where.eq('phone', identifier));
  }

  Future<Map<String, dynamic>?> getUser(String identifier) => getUserByEmail(identifier);

  Future<bool> createUser(Map<String, dynamic> userData) async {
    return insertOne('users', userData);
  }

  Future<bool> updateUser(String identifier, Map<String, dynamic> updates) async {
    // 1. Update Profile in Unified DB
    var modifier = modify;
    bool hasProfileUpdates = false;
    
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
        modifier = modifier.set(entry.key, entry.value);
        hasProfileUpdates = true;
      }
    }

    if (hasProfileUpdates) {
      // Try to find by email or phone for the update selector
      await updateOne('users', 
        where.eq('email', identifier).or(where.eq('phone', identifier)), 
        modifier, upsert: true);
    }

    // 2. Sync Location (for geospatial SOS alerts)
    if (locationPoint != null) {
      var locModifier = modify
          .set('location', locationPoint)
          .set('lastSeen', DateTime.now().toIso8601String())
          .set('identifier', identifier);
      
      if (updates.containsKey('name')) locModifier = locModifier.set('name', updates['name']);
      if (updates.containsKey('phone')) locModifier = locModifier.set('phone', updates['phone']);
      if (updates.containsKey('email')) locModifier = locModifier.set('email', updates['email']);

      await updateOne('user_locations', 
        where.eq('identifier', identifier), 
        locModifier, upsert: true);
    }

    return true;
  }

  Future<List<Map<String, dynamic>>> getNearbyUsers(double lat, double lon, double radiusKm) async {
    return executeWithRetry(() async {
      final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
      
      final selector = {
        'location': {
          '$nearSphere': {
            '$geometry': {
              'type': 'Point',
              'coordinates': [lon, lat]
            },
            '$maxDistance': radiusKm * 1000
          }
        },
        'lastSeen': {'$gt': twentyFourHoursAgo}
      };

      return await find('user_locations', where.raw(selector));
    });
  }

  // ─── SOS Methods ─────────────────────────────────────────────────────────

  Future<bool> createSOS(Map<String, dynamic> sosData) => insertOne('sos_history', sosData);

  Future<List<Map<String, dynamic>>> getUserSOSHistory(String phone) => find('sos_history', where.eq('user_phone', phone));

  Future<bool> updateSOSStatus(String sosId, String status) async {
    try {
      return await updateOne('sos_history', where.eq('_id', ObjectId.parse(sosId)), modify.set('status', status));
    } catch (e) {
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
            .set('user_email', email)
            .set('user_phone', contactData['user_phone'] ?? ''),
      upsert: true,
    );
  }

  Future<List<Map<String, dynamic>>> getContacts(String identifier) {
    return find('emergency_contacts', where.eq('user_email', identifier).or(where.eq('user_phone', identifier)));
  }

  Future<List<Map<String, dynamic>>> getContactsForUser({String? email, String? phone}) async {
    return find('emergency_contacts', where.eq('user_email', email).or(where.eq('user_phone', phone)));
  }

  Future<bool> deleteContact(String contactId) async {
    try {
      final result = await getCollection('emergency_contacts').deleteOne(where.eq('_id', ObjectId.parse(contactId)));
      return result.isSuccess;
    } catch (e) {
      final result = await getCollection('emergency_contacts').deleteOne(where.eq('id', contactId));
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
      final selector = {
        'location': {
          '$nearSphere': {
            '$geometry': {
              'type': 'Point',
              'coordinates': [lon, lat]
            },
            '$maxDistance': radiusKm * 1000
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
