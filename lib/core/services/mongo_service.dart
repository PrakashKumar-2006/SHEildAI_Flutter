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
      
      if (_connectionString == null || _connectionString!.isEmpty) {
        throw Exception('MongoDB connection string not found in environment variables');
      }
      
      _db = await Db.create(_connectionString!);
      await _db!.open();
      _isConnected = true;
    } catch (e) {
      _isConnected = false;
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

  Future<bool> createUser(Map<String, dynamic> userData) async {
    try {
      final collection = getCollection('users');
      await collection.insertOne(userData);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateUser(String phone, Map<String, dynamic> updates) async {
    try {
      final collection = getCollection('users');
      final result = await collection.updateOne(
        where.eq('phone', phone),
        modify.set(updates.keys.first, updates.values.first),
      );
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
  Future<bool> addContact(String phone, Map<String, dynamic> contactData) async {
    try {
      final collection = getCollection('emergency_contacts');
      contactData['user_phone'] = phone;
      await collection.insertOne(contactData);
      return true;
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

  Future<bool> deleteContact(String contactId) async {
    try {
      final collection = getCollection('emergency_contacts');
      final result = await collection.deleteOne(where.eq('_id', ObjectId.parse(contactId)));
      return result.isSuccess;
    } catch (e) {
      return false;
    }
  }

  // Community reports operations
  Future<bool> submitCommunityReport(Map<String, dynamic> reportData) async {
    try {
      final collection = getCollection('community_reports');
      await collection.insertOne(reportData);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getNearbyReports(double lat, double lon, double radiusKm) async {
    try {
      final collection = getCollection('community_reports');
      final result = await collection.find().toList();
      return result;
    } catch (e) {
      return [];
    }
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
