import 'dart:convert';
import 'package:http/http.dart' as http;

class MLService {
  static const String baseUrl = 'https://prakashkumarbiswal-sheildai-ml.hf.space/api';
  
  Future<Map<String, dynamic>> _postWithRetry(String endpoint, Map<String, dynamic> body) async {
    int retries = 0;
    while (retries < 3) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else if (response.statusCode == 503 || response.statusCode == 404) {
          // HF Space might be sleeping
          retries++;
          await Future.delayed(Duration(seconds: 2 * retries));
        } else {
          throw Exception('Failed to call ML API: ${response.statusCode}');
        }
      } catch (e) {
        retries++;
        if (retries >= 3) rethrow;
        await Future.delayed(Duration(seconds: 2 * retries));
      }
    }
    throw Exception('ML API call failed after retries');
  }

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
    return _postWithRetry('risk', {
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
    });
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
    return _postWithRetry('safe-route-v2', {
      'origin_lat': originLat,
      'origin_lon': originLon,
      'dest_lat': destLat,
      'dest_lon': destLon,
      'hour': hour,
      'month': month,
      'is_weekend': isWeekend,
      'routes': routes,
    });
  }

  // Best Travel Time - Safest travel window in next 24 hours
  Future<Map<String, dynamic>> getBestTravelTime({
    required double lat,
    required double lon,
    required int month,
    int isWeekend = 0,
    int topN = 3,
  }) async {
    return _postWithRetry('best-travel-time', {
      'lat': lat,
      'lon': lon,
      'month': month,
      'is_weekend': isWeekend,
      'top_n': topN,
    });
  }

  // Forecast - 3-hour risk forecast
  Future<Map<String, dynamic>> getForecast({
    required double lat,
    required double lon,
    required int currentHour,
    required int month,
    int isWeekend = 0,
  }) async {
    return _postWithRetry('forecast', {
      'lat': lat,
      'lon': lon,
      'current_hour': currentHour,
      'month': month,
      'is_weekend': isWeekend,
    });
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
    return _postWithRetry('community-alert', {
      'lat': lat,
      'lon': lon,
      'hour': hour,
      'month': month,
      'incident_type': incidentType,
      'description': description,
      'anonymous': anonymous,
      'severity': severity,
    });
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
    return _postWithRetry('sos', {
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
    });
  }
}
