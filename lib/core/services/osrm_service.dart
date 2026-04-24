import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

class OSRMService {
  static const String _osrmBaseUrl = 'https://router.project-osrm.org/route/v1/driving';
  static const String _nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

  /// Geocode a destination string to get coordinates
  static Future<LatLng?> geocodeDestination(String destination, double originLat, double originLon) async {
    try {
      // Add lat/lon bias for location search (prioritizes nearby locations)
      final url = Uri.parse(
        '$_nominatimBaseUrl/search?q=${Uri.encodeComponent(destination)}&format=json&limit=1&lat=$originLat&lon=$originLon'
      );
      
      final response = await http.get(
        url,
        headers: {'User-Agent': 'SHEild AI/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[OSRM] Geocoding error: $e');
      return null;
    }
  }

  /// Get multiple route alternatives from OSRM
  static Future<List<OSRMRoute>> getRoutes(
    double originLat,
    double originLon,
    double destLat,
    double destLon, {
    int alternatives = 3,
  }) async {
    try {
      final url = Uri.parse(
        '$_osrmBaseUrl/$originLon,$originLat;$destLon,$destLat?overview=full&geometries=polyline&alternatives=$alternatives'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['code'] != 'Ok' || data['routes'] == null) {
          debugPrint('[OSRM] OSRM returned non-OK code: ${data['code']}');
          return [];
        }

        final routes = <OSRMRoute>[];
        
        for (int i = 0; i < data['routes'].length; i++) {
          final route = data['routes'][i];
          final points = _decodePolyline(route['geometry']);
          
          routes.add(OSRMRoute(
            index: i,
            points: points,
            duration: route['duration'] ?? 0,
            distance: route['distance'] ?? 0,
            geometry: route['geometry'],
          ));
        }

        return routes;
      }
      return [];
    } catch (e) {
      debugPrint('[OSRM] Route fetching error: $e');
      return [];
    }
  }

  /// Decode Google polyline format
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  /// Calculate distance between two points in meters using Haversine formula
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Earth's radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final radLat1 = _toRadians(lat1);
    final radLat2 = _toRadians(lat2);
    
    final a = 
        pow(sin(dLat / 2), 2) +
        cos(radLat1) * cos(radLat2) * pow(sin(dLon / 2), 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }
}

class OSRMRoute {
  final int index;
  final List<LatLng> points;
  final double duration; // in seconds
  final double distance; // in meters
  final String geometry;
  
  double get durationMinutes => duration / 60;
  double get distanceKm => distance / 1000;
  String get formattedDuration {
    final mins = durationMinutes.round();
    if (mins < 60) return '$mins mins';
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    return '$hours h $remainingMins m';
  }
  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';

  OSRMRoute({
    required this.index,
    required this.points,
    required this.duration,
    required this.distance,
    required this.geometry,
  });
}
