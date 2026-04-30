import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoService {
  static final MongoService _instance = MongoService._internal();
  factory MongoService() => _instance;

  MongoService._internal();

  String? _connectionString;
  
  Db? _db;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  Db? get database => _db;

  Future<void> connect() async {
    try {
      _connectionString = dotenv.env['MONGO_DB_CONNECTION_STRING'];
      final dbName = dotenv.env['MONGO_DB_NAME'] ?? 'sheildai';
      
      debugPrint('[MongoService] Connecting to Atlas (DB: $dbName)...');
      
      if (_connectionString == null || _connectionString!.isEmpty) {
        throw Exception('MongoDB connection string missing in .env');
      }

      String finalUri = _connectionString!;
      
      // If URI doesn't have a database name, inject it before the query parameters
      if (finalUri.contains('.net/') && !finalUri.contains('.net/$dbName')) {
        finalUri = finalUri.replaceFirst('.net/', '.net/$dbName');
      }
      
      debugPrint('[MongoService] Connecting with URI: ${finalUri.replaceFirst(RegExp(r':.*@'), ':****@')}');
      
      _db = await Db.create(finalUri);
      await _db!.open();
      
      _isConnected = true;
      debugPrint('[MongoService] SUCCESS: Connected to Atlas DB: $dbName');
      
      // Ensure geo-spatial index exists for community reports
      try {
        final collection = _db!.collection('community_reports');
        // We use createIndex to ensure the 'location' field is searchable via geo-queries
        await collection.createIndex(keys: {'location': '2dsphere'});
        debugPrint('[MongoService] Geo-index verified for community_reports');
      } catch (e) {
        debugPrint('[MongoService] Note: Geo-index check skipped or index exists: $e');
      }
    } catch (e) {
      _isConnected = false;
      debugPrint('[MongoService] FAILED to connect: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (_db != null && _isConnected) {
      await _db!.close();
      _isConnected = false;
    }
  }

  DbCollection getCollection(String collectionName) {
    if (_db == null || !_isConnected) {
      throw Exception('MongoDB not connected. Call connect() first.');
    }
    return _db!.collection(collectionName);
  }

  // User operations
  Future<Map<String, dynamic>?> getUser(String phone) async {
    try {
      final collection = getCollection('users');
      final result = await collection.findOne(where.eq('phone', phone));
      return result;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final collection = getCollection('users');
      final result = await collection.findOne(where.eq('email', email));
      return result;
    } catch (e) {
      return null;
    }
  }

  Future<bool> createUser(Map<String, dynamic> userData) async {
    try {
      final collection = getCollection('users');
      debugPrint('Inserting user into MongoDB: ${userData['email']}');
      await collection.insertOne(userData);
      debugPrint('SUCCESS: User inserted into MongoDB');
      return true;
    } catch (e) {
      debugPrint('FAILED to create user in MongoDB: $e');
      return false;
    }
  }

  Future<bool> updateUser(String email, Map<String, dynamic> updates) async {
    try {
      final collection = getCollection('users');
      final result = await collection.updateOne(
        where.eq('email', email),
        modify.set(updates.keys.first, updates.values.first),
      );
      // If there are more keys, update them too (simple loop for robust updates)
      if (updates.length > 1) {
        for (var entry in updates.entries.skip(1)) {
          await collection.updateOne(
            where.eq('email', email),
            modify.set(entry.key, entry.value),
          );
        }
      }
      return result.isSuccess;
    } catch (e) {
      return false;
    }
  }

  // SOS operations
  Future<bool> createSOS(Map<String, dynamic> sosData) async {
    try {
      final collection = getCollection('sos_history');
      await collection.insertOne(sosData);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getUserSOSHistory(String phone) async {
    try {
      final collection = getCollection('sos_history');
      final result = await collection.find(where.eq('user_phone', phone)).toList();
      return result;
    } catch (e) {
      return [];
    }
  }

  Future<bool> updateSOSStatus(String sosId, String status) async {
    try {
      final collection = getCollection('sos_history');
      final result = await collection.updateOne(
        where.eq('_id', ObjectId.parse(sosId)),
        modify.set('status', status),
      );
      return result.isSuccess;
    } catch (e) {
      return false;
    }
  }

  // Emergency contacts operations
  Future<bool> addContact(String email, Map<String, dynamic> contactData) async {
    try {
      final collection = getCollection('emergency_contacts');
      contactData['user_email'] = email;
      
      // Use upsert to avoid duplicates based on user_email and contact phone
      final result = await collection.updateOne(
        where.eq('user_email', email).and(where.eq('phone', contactData['phone'])),
        modify.set('name', contactData['name'])
              .set('relationship', contactData['relationship'] ?? 'Guardian')
              .set('user_email', email),
        upsert: true,
      );
      return result.isSuccess;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getContacts(String phone) async {
    try {
      final collection = getCollection('emergency_contacts');
      final result = await collection.find(where.eq('user_phone', phone)).toList();
      return result;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getContactsByEmail(String email) async {
    try {
      final collection = getCollection('emergency_contacts');
      final result = await collection.find(where.eq('user_email', email)).toList();
      return result;
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteContact(String contactId) async {
    try {
      final collection = getCollection('emergency_contacts');
      final result = await collection.deleteOne(where.eq('_id', ObjectId.parse(contactId)));
      return result.isSuccess;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateContact(String contactId, Map<String, dynamic> updates) async {
    try {
      final collection = getCollection('emergency_contacts');
      var modifier = modify;
      for (var entry in updates.entries) {
        modifier = modifier.set(entry.key, entry.value);
      }
      final result = await collection.updateOne(
        where.eq('_id', ObjectId.parse(contactId)),
        modifier,
      );
      return result.isSuccess;
    } catch (e) {
      return false;
    }
  }

  // Alert operations
  Future<bool> createAlert(Map<String, dynamic> alertData) async {
    try {
      final collection = getCollection('alerts');
      await collection.insertOne(alertData);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAlerts(String email) async {
    try {
      final collection = getCollection('alerts');
      final result = await collection.find(where.eq('user_email', email)).toList();
      return result;
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteAlert(String alertId) async {
    try {
      final collection = getCollection('alerts');
      final result = await collection.deleteOne(where.eq('_id', ObjectId.parse(alertId)));
      return result.isSuccess;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateAlert(String alertId, Map<String, dynamic> updates) async {
    try {
      final collection = getCollection('alerts');
      var modifier = modify;
      for (var entry in updates.entries) {
        modifier = modifier.set(entry.key, entry.value);
      }
      final result = await collection.updateOne(
        where.eq('_id', ObjectId.parse(alertId)),
        modifier,
      );
      return result.isSuccess;
    } catch (e) {
      return false;
    }
  }

  Future<void> _ensureConnected() async {
    if (_db == null || !_isConnected || !_db!.isConnected) {
      debugPrint('[MongoService] DB not connected, attempting reconnect...');
      await connect();
    }
  }

  // Community reports operations
  Future<bool> submitCommunityReport(Map<String, dynamic> reportData) async {
    try {
      await _ensureConnected();
      final collection = getCollection('community_reports');
      
      final timestamp = DateTime.now();
      reportData['timestamp'] = timestamp.toIso8601String();
      reportData['created_at'] = timestamp.millisecondsSinceEpoch;
      
      final lat = (reportData['lat'] ?? reportData['latitude'] as num).toDouble();
      final lon = (reportData['lon'] ?? reportData['longitude'] as num).toDouble();
      
      // GEO-JSON format: [longitude, latitude]
      reportData['location'] = {
        'type': 'Point',
        'coordinates': [lon, lat]
      };
      
      reportData['lat'] = lat;
      reportData['lon'] = lon;
      
      await collection.insertOne(reportData);
      debugPrint('[MongoService] SUCCESS: Report stored in Atlas');
      return true;
    } catch (e) {
      debugPrint('[MongoService] ERROR: Failed to store report: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyReports(double lat, double lon, double radiusKm) async {
    try {
      await _ensureConnected();
      final collection = getCollection('community_reports');
      
      debugPrint('[MongoService] Fetching reports near $lat, $lon (radius: ${radiusKm}km)');
      
      // Try using geo-spatial query first
      try {
        final result = await collection.find({
          'location': {
            '\$near': {
              '\$geometry': {
                'type': 'Point',
                'coordinates': [lon, lat]
              },
              '\$maxDistance': radiusKm * 1000 // meters
            }
          }
        }).toList();
        
        debugPrint('[MongoService] Found ${result.length} reports via geo-query');
        return result;
      } catch (e) {
        // Fallback: Fetch last 100 reports and filter locally
        debugPrint('[MongoService] Geo-query failed or index missing, falling back: $e');
        final all = await collection.find(
          where.sortBy('created_at', descending: true).limit(100)
        ).toList();
        
        final filtered = all.where((rpt) {
          final rlat = (rpt['lat'] ?? rpt['latitude'] as num).toDouble();
          final rlon = (rpt['lon'] ?? rpt['longitude'] as num).toDouble();
          final dist = _calculateDistance(lat, lon, rlat, rlon);
          return dist <= radiusKm;
        }).toList();
        
        debugPrint('[MongoService] Found ${filtered.length} reports via fallback filter');
        return filtered;
      }
    } catch (e) {
      debugPrint('[MongoService] getNearbyReports error: $e');
      return [];
    }
  }

  // Determine nearby users for SOS broadcast logic
  Future<List<Map<String, dynamic>>> getNearbyUsers(double lat, double lon, double radiusKm) async {
    try {
      final collection = getCollection('users');
      // Similar geo-query logic for users
      final result = await collection.find().toList(); // For now, get all and filter locally for safety
      return result.where((u) {
        if (u['last_lat'] == null || u['last_lon'] == null) return false;
        final dist = _calculateDistance(lat, lon, u['last_lat'], u['last_lon']);
        return dist <= radiusKm;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Standard Haversine formula
    const double R = 6371.0; // Earth radius in km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = 
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * 
      sin(dLon / 2) * sin(dLon / 2);
      
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * (3.141592653589793 / 180.0);
  }

  // Location logs operations
  Future<bool> saveLocationLog(Map<String, dynamic> locationData) async {
    try {
      final collection = getCollection('location_logs');
      await collection.insertOne(locationData);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getLocationLogs(String phone, {DateTime? startDate, DateTime? endDate}) async {
    try {
      final collection = getCollection('location_logs');
      var query = where.eq('user_phone', phone);
      
      if (startDate != null) {
        query = query.gte('timestamp', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('timestamp', endDate.toIso8601String());
      }
      
      final result = await collection.find(query).toList();
      return result;
    } catch (e) {
      return [];
    }
  }

  // Subscription operations
  Future<bool> createSubscription(Map<String, dynamic> subscriptionData) async {
    try {
      final collection = getCollection('subscriptions');
      await collection.insertOne(subscriptionData);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getActiveSubscription(String phone) async {
    try {
      final collection = getCollection('subscriptions');
      final now = DateTime.now();
      final result = await collection.findOne(
        where.eq('user_phone', phone)
          .eq('isActive', true)
          .gt('endDate', now.toIso8601String()),
      );
      return result;
    } catch (e) {
      return null;
    }
  }

  // Profile operations
  Future<bool> updateProfile(String phone, Map<String, dynamic> profileData) async {
    try {
      final collection = getCollection('users');
      final result = await collection.updateOne(
        where.eq('phone', phone),
        modify.set('profile', profileData),
      );
      return result.isSuccess;
    } catch (e) {
      return false;
    }
  }
}
