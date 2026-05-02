import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

class ApiService {
  static const String _backendUrl = 'https://sheildai1-o.onrender.com';
  static const String _mlApiUrl = 'https://prakashkumarbiswal-sheildai-ml.hf.space/api';
  static const Duration _timeout = Duration(seconds: 15);
  
  static const String _tokenPrefix = 'auth_token_';

  static Future<http.Response> _fetchWithTimeout(String url, Map<String, String>? headers, String? body) async {
    try {
      final response = await http
          .post(Uri.parse(url), headers: headers, body: body)
          .timeout(_timeout);
      return response;
    } on TimeoutException {
      throw Exception('Request timed out after ${_timeout.inSeconds} seconds');
    }
  }

  static Future<bool> pingBackend() async {
    try {
      final response = await http.get(Uri.parse('$_backendUrl/api/health')).timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getAuthToken(String phone, {int retryCount = 0}) async {
    try {
      // Try to get existing token from StorageService
      final storageService = StorageService();
      final cachedToken = storageService.getString('$_tokenPrefix$phone');
      if (cachedToken != null) {
        return cachedToken;
      }
      
      // Generate new token
      final response = await _fetchWithTimeout(
        '$_backendUrl/api/auth/token',
        {'Content-Type': 'application/json'},
        jsonEncode({'phone': phone}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String?;
        
        // Store token in StorageService
        if (token != null) {
          await storageService.setString('$_tokenPrefix$phone', token);
        }
        
        return token;
      }

      if (retryCount < 5) {
        await Future.delayed(const Duration(seconds: 5));
        return getAuthToken(phone, retryCount: retryCount + 1);
      }
      return null;
    } catch (e) {
      if (retryCount < 5) {
        await Future.delayed(const Duration(seconds: 5));
        return getAuthToken(phone, retryCount: retryCount + 1);
      }
      return null;
    }
  }

  static Future<void> clearAuthToken(String phone) async {
    try {
      final storageService = StorageService();
      await storageService.remove('$_tokenPrefix$phone');
    } catch (e) {
      // Ignore errors on clear
    }
  }

  static Future<void> syncUserLocation(String phone, double? latitude, double? longitude, String? name, {int retryCount = 0}) async {
    try {
      final token = await getAuthToken(phone);
      if (token == null) return;

      final response = await _fetchWithTimeout(
        '$_backendUrl/api/users/location',
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        jsonEncode({
          'user_id': phone,
          'latitude': latitude,
          'longitude': longitude,
          'name': name,
        }),
      );
      
      if (response.statusCode != 200 && retryCount < 5) {
        await Future.delayed(const Duration(seconds: 5));
        return syncUserLocation(phone, latitude, longitude, name, retryCount: retryCount + 1);
      }
    } catch (e) {
      if (retryCount < 5) {
        await Future.delayed(const Duration(seconds: 5));
        return syncUserLocation(phone, latitude, longitude, name, retryCount: retryCount + 1);
      }
    }
  }

  static Future<void> triggerCloudSOS(String phone, double latitude, double longitude, {int retryCount = 0}) async {
    try {
      final token = await getAuthToken(phone);
      if (token == null) return;

      final response = await _fetchWithTimeout(
        '$_backendUrl/api/sos/trigger',
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        jsonEncode({
          'user_id': phone,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );
      
      if (response.statusCode != 200 && retryCount < 5) {
        await Future.delayed(const Duration(seconds: 5));
        return triggerCloudSOS(phone, latitude, longitude, retryCount: retryCount + 1);
      }
    } catch (e) {
      if (retryCount < 5) {
        await Future.delayed(const Duration(seconds: 5));
        return triggerCloudSOS(phone, latitude, longitude, retryCount: retryCount + 1);
      }
    }
  }

  // User Profile methods
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final token = await getAuthToken(userId);
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_backendUrl/api/users/profile/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateUserProfile(Map<String, dynamic> profile) async {
    try {
      final userId = profile['phone'] ?? profile['email'];
      final token = await getAuthToken(userId);
      if (token == null) return null;

      final response = await _fetchWithTimeout(
        '$_backendUrl/api/users/profile/update',
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        jsonEncode(profile),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchHotspots() async {
    try {
      final response = await http
          .get(Uri.parse('$_backendUrl/api/zones/hotspots'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] Error fetching hotspots: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchNearbyCommunityReports(double lat, double lon, double radiusKm) async {
    try {
      final response = await http
          .get(Uri.parse('$_backendUrl/api/community-reports?lat=$lat&lon=$lon&radius=$radiusKm'))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      debugPrint('[ApiService] Error fetching nearby reports: $e');
      return null;
    }
  }

  static Future<bool> submitCommunityReport(Map<String, dynamic> report, {int retryCount = 0}) async {
    try {
      final userId = report['phone'];
      final token = await getAuthToken(userId);
      if (token == null) return false;

      final response = await _fetchWithTimeout(
        '$_backendUrl/api/community-reports',
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        jsonEncode(report),
      );
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (retryCount < 3) {
        await Future.delayed(const Duration(seconds: 3));
        return submitCommunityReport(report, retryCount: retryCount + 1);
      }
      return false;
    }
  }
}
