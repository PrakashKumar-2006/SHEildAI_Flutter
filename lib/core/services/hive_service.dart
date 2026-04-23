import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;

  HiveService._internal();

  static const String _sosHistoryBox = 'sos_history';
  static const String _contactsBox = 'contacts';
  static const String _locationLogsBox = 'location_logs';

  Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Register adapters if needed
    // Hive.registerAdapter(SOSModelAdapter());
    // Hive.registerAdapter(LocationModelAdapter());
    // Hive.registerAdapter(ContactModelAdapter());
    
    // Open boxes
    await Hive.openBox(_sosHistoryBox);
    await Hive.openBox(_contactsBox);
    await Hive.openBox(_locationLogsBox);
  }

  // SOS History operations
  Future<void> saveSOS(Map<String, dynamic> sosData) async {
    final box = Hive.box(_sosHistoryBox);
    await box.put(sosData['id'], sosData);
  }

  Future<List<Map<String, dynamic>>> getSOSHistory() async {
    final box = Hive.box(_sosHistoryBox);
    final data = box.values.toList().cast<Map<String, dynamic>>();
    // Sort by timestamp descending
    data.sort((a, b) {
      final aTime = DateTime.parse(a['timestamp'] as String);
      final bTime = DateTime.parse(b['timestamp'] as String);
      return bTime.compareTo(aTime);
    });
    return data;
  }

  Future<void> updateSOSStatus(String sosId, String status) async {
    final box = Hive.box(_sosHistoryBox);
    final sosData = box.get(sosId);
    if (sosData != null) {
      sosData['status'] = status;
      await box.put(sosId, sosData);
    }
  }

  Future<void> deleteSOS(String sosId) async {
    final box = Hive.box(_sosHistoryBox);
    await box.delete(sosId);
  }

  // Emergency contacts operations
  Future<void> saveContact(Map<String, dynamic> contactData) async {
    final box = Hive.box(_contactsBox);
    await box.put(contactData['id'], contactData);
  }

  Future<List<Map<String, dynamic>>> getContacts() async {
    final box = Hive.box(_contactsBox);
    return box.values.toList().cast<Map<String, dynamic>>();
  }

  Future<void> deleteContact(String contactId) async {
    final box = Hive.box(_contactsBox);
    await box.delete(contactId);
  }

  // Location logs operations
  Future<void> saveLocationLog(Map<String, dynamic> locationData) async {
    final box = Hive.box(_locationLogsBox);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    await box.put(timestamp, locationData);
    
    // Keep only last 1000 location logs
    if (box.length > 1000) {
      final keys = box.keys.toList();
      keys.sort();
      await box.delete(keys.first);
    }
  }

  Future<List<Map<String, dynamic>>> getLocationLogs({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final box = Hive.box(_locationLogsBox);
    final data = box.values.toList().cast<Map<String, dynamic>>();
    
    if (startDate != null || endDate != null) {
      return data.where((log) {
        final logTime = DateTime.parse(log['timestamp'] as String);
        if (startDate != null && logTime.isBefore(startDate)) return false;
        if (endDate != null && logTime.isAfter(endDate)) return false;
        return true;
      }).toList();
    }
    
    // Sort by timestamp descending
    data.sort((a, b) {
      final aTime = DateTime.parse(a['timestamp'] as String);
      final bTime = DateTime.parse(b['timestamp'] as String);
      return bTime.compareTo(aTime);
    });
    
    return data;
  }

  Future<void> clearLocationLogs() async {
    final box = Hive.box(_locationLogsBox);
    await box.clear();
  }

  // Clear all data
  Future<void> clearAll() async {
    await Hive.box(_sosHistoryBox).clear();
    await Hive.box(_contactsBox).clear();
    await Hive.box(_locationLogsBox).clear();
  }

  void dispose() {
    Hive.close();
  }
}
