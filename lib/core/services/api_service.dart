import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'hive_service.dart';

class ApiService {
  static const String _backendUrl = 'https://sheildai1-o.onrender.com';
  static const String _mlApiUrl = 'https://prakashkumarbiswal-sheildai-ml.hf.space/api';
  static const Duration _timeout = Duration(seconds: 15);
  
  static const String _tokenBoxName = 'auth_tokens';

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
      // Try to get existing token from Hive
      final hiveService = HiveService();
      await hiveService.openBox(_tokenBoxName);
      final cachedToken = await hiveService.get(_tokenBoxName, phone);
      if (cachedToken != null) {
        return cachedToken as String?;
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
        
        // Store token in Hive
        if (token != null) {
          await hiveService.put(_tokenBoxName, phone, token);
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
      final hiveService = HiveService();
      await hiveService.openBox(_tokenBoxName);
      await hiveService.delete(_tokenBoxName, phone);
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

      if (response.statusCode != 200 && retryCount < 3) {
        await Future.delayed(const Duration(seconds: 4));
        return syncUserLocation(phone, latitude, longitude, name, retryCount: retryCount + 1);
      }
    } catch (e) {
      if (retryCount < 3) {
        await Future.delayed(const Duration(seconds: 4));
        return syncUserLocation(phone, latitude, longitude, name, retryCount: retryCount + 1);
      }
    }
  }

  static Future<Map<String, dynamic>?> triggerCloudSOS(String phone, double latitude, double longitude) async {
    try {
      final token = await getAuthToken(phone);
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

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchPredictedRisk(double latitude, double longitude) async {
    try {
      final now = DateTime.now();
      final response = await _fetchWithTimeout(
        '$_mlApiUrl/risk',
        {'Content-Type': 'application/json'},
        jsonEncode({
          'lat': latitude,
          'lon': longitude,
          'hour': now.hour,
          'month': now.month + 1,
          'transport_mode': 'walking',
          'internet': true,
          'battery': 80,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchForecast(double lat, double lon, int currentHour, int month) async {
    try {
      final response = await _fetchWithTimeout(
        '$_mlApiUrl/forecast',
        {'Content-Type': 'application/json'},
        jsonEncode({
          'lat': lat,
          'lon': lon,
          'current_hour': currentHour,
          'month': month,
          'is_weekend': 0,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchBestTravelTime(double lat, double lon, int month) async {
    try {
      final response = await _fetchWithTimeout(
        '$_mlApiUrl/best-travel-time',
        {'Content-Type': 'application/json'},
        jsonEncode({
          'lat': lat,
          'lon': lon,
          'month': month,
          'is_weekend': 0,
          'top_n': 3,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> submitCommunityReport(
    String phone,
    double latitude,
    double longitude,
    String incidentType,
    String description,
    int severity,
    {bool anonymous = true}
  ) async {
    try {
      final token = await getAuthToken(phone);
      final response = await _fetchWithTimeout(
        '$_backendUrl/api/community-reports',
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'incidentType': incidentType,
          'description': description,
          'severity': severity,
          'anonymous': anonymous,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<dynamic>?> fetchNearbyCommunityReports(double latitude, double longitude) async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/community-reports?latitude=$latitude&longitude=$longitude&radiusKm=10'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSafeRouteV2(
    double originLat,
    double originLon,
    double destLat,
    double destLon,
    int hour,
    int month,
    List<List<Map<String, double>>> routes,
  ) async {
    try {
      final response = await _fetchWithTimeout(
        '$_mlApiUrl/safe-route-v2',
        {'Content-Type': 'application/json'},
        jsonEncode({
          'origin_lat': originLat,
          'origin_lon': originLon,
          'dest_lat': destLat,
          'dest_lon': destLon,
          'hour': hour,
          'month': month,
          'is_weekend': 0,
          'routes': routes,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<dynamic>?> fetchHotspots() async {
    try {
      final response = await http.get(
        Uri.parse('$_mlApiUrl/hotspots?min_risk=56'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSafetyForecast(double latitude, double longitude) async {
    try {
      final response = await _fetchWithTimeout(
        '$_mlApiUrl/forecast',
        {'Content-Type': 'application/json'},
        jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getBestTravelTime(
    double originLat,
    double originLon,
    double destLat,
    double destLon,
  ) async {
    try {
      final response = await _fetchWithTimeout(
        '$_mlApiUrl/best-travel-time',
        {'Content-Type': 'application/json'},
        jsonEncode({
          'origin_lat': originLat,
          'origin_lon': originLon,
          'dest_lat': destLat,
          'dest_lon': destLon,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<dynamic>?> getHotspots(double latitude, double longitude, double radiusKm) async {
    try {
      final response = await http.get(
        Uri.parse('$_mlApiUrl/hotspots?latitude=$latitude&longitude=$longitude&radiusKm=$radiusKm&min_risk=56'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/api/user/$userId'),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      final token = await getAuthToken(profileData['phone'] as String);
      if (token == null) return null;

      final response = await _fetchWithTimeout(
        '$_backendUrl/api/user/update',
        {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        jsonEncode(profileData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
