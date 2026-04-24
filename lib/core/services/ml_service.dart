import 'dart:convert';
import 'package:http/http.dart' as http;

class MLService {
  static const String baseUrl = 'http://10.0.2.2:8000';  // Use 10.0.2.2 for Android emulator
  
  // Risk Prediction
  Future<Map<String, dynamic>> predictRisk({
    required double lat,
    required double lon,
    required int hour,
    required int month,
    String transportMode = 'walking',
    String? cctv,
    String? lighting,
    bool internet = true,
    int battery = 100,
    String? crimeType,
    int? isWeekend,
    String? weather,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/risk'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': lat,
          'lon': lon,
          'hour': hour,
          'month': month,
          'transport_mode': transportMode,
          'cctv': cctv,
          'lighting': lighting,
          'internet': internet,
          'battery': battery,
          'crime_type': crimeType,
          'is_weekend': isWeekend,
          'weather': weather,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to predict risk: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Risk prediction error: $e');
    }
  }

  // Safe Route V2 - Route ranking with danger circle overlays
  Future<Map<String, dynamic>> getSafeRouteV2({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required int hour,
    required int month,
    int isWeekend = 0,
    required List<List<Map<String, double>>> routes,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/safe-route-v2'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'origin_lat': originLat,
          'origin_lon': originLon,
          'dest_lat': destLat,
          'dest_lon': destLon,
          'hour': hour,
          'month': month,
          'is_weekend': isWeekend,
          'routes': routes,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get safe route: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Safe route error: $e');
    }
  }

  // Best Travel Time - Safest travel window in next 24 hours
  Future<Map<String, dynamic>> getBestTravelTime({
    required double lat,
    required double lon,
    required int month,
    int isWeekend = 0,
    int topN = 3,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/best-travel-time'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': lat,
          'lon': lon,
          'month': month,
          'is_weekend': isWeekend,
          'top_n': topN,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get best travel time: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Best travel time error: $e');
    }
  }

  // Forecast - 3-hour risk forecast
  Future<Map<String, dynamic>> getForecast({
    required double lat,
    required double lon,
    required int currentHour,
    required int month,
    int isWeekend = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/forecast'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': lat,
          'lon': lon,
          'current_hour': currentHour,
          'month': month,
          'is_weekend': isWeekend,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get forecast: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Forecast error: $e');
    }
  }

  // Community Alert
  Future<Map<String, dynamic>> submitCommunityAlert({
    required double lat,
    required double lon,
    required int hour,
    required int month,
    required String incidentType,
    String description = '',
    bool anonymous = true,
    int severity = 5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/community-alert'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': lat,
          'lon': lon,
          'hour': hour,
          'month': month,
          'incident_type': incidentType,
          'description': description,
          'anonymous': anonymous,
          'severity': severity,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to submit alert: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Community alert error: $e');
    }
  }

  // SOS
  Future<Map<String, dynamic>> triggerSOS({
    required double lat,
    required double lon,
    required int hour,
    required int month,
    String triggerType = 'button',
    required List<String> emergencyContacts,
    bool internet = true,
    int battery = 100,
    bool audioRecording = false,
    bool videoRecording = false,
    String? sessionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/sos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': lat,
          'lon': lon,
          'hour': hour,
          'month': month,
          'trigger_type': triggerType,
          'emergency_contacts': emergencyContacts,
          'internet': internet,
          'battery': battery,
          'audio_recording': audioRecording,
          'video_recording': videoRecording,
          'session_id': sessionId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to trigger SOS: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('SOS error: $e');
    }
  }
}
