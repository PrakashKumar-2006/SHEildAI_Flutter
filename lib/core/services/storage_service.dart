import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;

  StorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Shared Preferences Methods
  Future<bool> setString(String key, String value) async {
    await init();
    return await _prefs!.setString(key, value);
  }

  Future<bool> setInt(String key, int value) async {
    await init();
    return await _prefs!.setInt(key, value);
  }

  Future<bool> setBool(String key, bool value) async {
    await init();
    return await _prefs!.setBool(key, value);
  }

  Future<bool> setDouble(String key, double value) async {
    await init();
    return await _prefs!.setDouble(key, value);
  }

  Future<bool> setStringList(String key, List<String> value) async {
    await init();
    return await _prefs!.setStringList(key, value);
  }

  String? getString(String key) {
    return _prefs?.getString(key);
  }

  int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  double? getDouble(String key) {
    return _prefs?.getDouble(key);
  }

  List<String>? getStringList(String key) {
    return _prefs?.getStringList(key);
  }

  Future<bool> remove(String key) async {
    await init();
    return await _prefs!.remove(key);
  }

  Future<bool> clear() async {
    await init();
    return await _prefs!.clear();
  }

  // Secure Storage Methods
  Future<void> setSecureString(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> getSecureString(String key) async {
    return await _secureStorage.read(key: key);
  }

  Future<void> removeSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  Future<void> clearSecure() async {
    await _secureStorage.deleteAll();
  }

  // JSON Methods
  Future<bool> setJson(String key, Map<String, dynamic> value) async {
    await init();
    return await _prefs!.setString(key, jsonEncode(value));
  }

  Map<String, dynamic>? getJson(String key) {
    final String? jsonString = _prefs?.getString(key);
    if (jsonString == null) return null;
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // App Specific Methods
  Future<bool> setUserName(String name) async {
    return await setString(AppConstants.keyUserName, name);
  }

  String getUserName() {
    return getString(AppConstants.keyUserName) ?? 'Safety Watcher';
  }

  Future<bool> setUserPhone(String phone) async {
    return await setString(AppConstants.keyUserPhone, phone);
  }

  String getUserPhone() {
    return getString(AppConstants.keyUserPhone) ?? '+919876543210';
  }

  Future<bool> setEmergencyContacts(List<Map<String, dynamic>> contacts) async {
    return await setStringList(
      AppConstants.keyEmergencyContacts,
      contacts.map((e) => jsonEncode(e)).toList(),
    );
  }

  List<Map<String, dynamic>> getEmergencyContacts() {
    final List<String>? contactsJson = getStringList(AppConstants.keyEmergencyContacts);
    if (contactsJson == null) return [];
    return contactsJson
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();
  }

  Future<bool> setLastSosTime(DateTime time) async {
    return await setInt(AppConstants.keyLastSosTime, time.millisecondsSinceEpoch);
  }

  DateTime? getLastSosTime() {
    final int? timestamp = getInt(AppConstants.keyLastSosTime);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<bool> setVoiceTriggerEnabled(bool enabled) async {
    return await setBool(AppConstants.keyVoiceTriggerEnabled, enabled);
  }

  bool getVoiceTriggerEnabled() {
    return getBool(AppConstants.keyVoiceTriggerEnabled) ?? false;
  }
}
