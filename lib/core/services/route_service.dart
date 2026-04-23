import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class RouteService {
  static const Duration _timeout = Duration(seconds: 15);

  // Decode Google polyline encoded string
  static List<Map<String, double>> decodePolyline(String encoded) {
    List<Map<String, double>> points = [];
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

      points.add({
        'latitude': lat / 1e5,
        'longitude': lng / 1e5,
      });
    }

    return points;
  }

  // Calculate distance between two points in km
  static double getDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  // Geocode destination to get coordinates
  static Future<Map<String, double>?> geocodeDestination(String destination, double lat, double lon) async {
    try {
      final url = 'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(destination)}&format=json&limit=1&lat=$lat&lon=$lon';
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'SHEild AI/1.0'}).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          return {
            'latitude': double.parse(data[0]['lat']),
            'longitude': double.parse(data[0]['lon']),
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Fetch routes from OSRM
  static Future<List<Map<String, dynamic>>> fetchOSRMRoutes(
    double originLat,
    double originLon,
    double destLat,
    double destLon,
    List<Map<String, dynamic>> riskZones,
  ) async {
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/$originLon,$originLat;$destLon,$destLat?overview=full&geometries=polyline&alternatives=3';
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok') {
          final routes = <Map<String, dynamic>>[];
          
          for (var i = 0; i < data['routes'].length; i++) {
            final route = data['routes'][i];
            final points = decodePolyline(route['geometry']);
            
            // Calculate risk score
            double totalRisk = 0;
            final sampleStep = math.max(1, (points.length / 100).floor());
            final sampledPoints = <Map<String, double>>[];
            
            for (var j = 0; j < points.length; j += sampleStep) {
              sampledPoints.add(points[j]);
            }
            
            for (final point in sampledPoints) {
              double pointMaxRisk = 0;
              for (final zone in riskZones) {
                final dist = getDistance(point['latitude']!, point['longitude']!, zone['lat'], zone['lon']);
                if (dist < 1.2) {
                  final riskImpact = zone['base_score'] * (1 - dist / 1.2);
                  if (riskImpact > pointMaxRisk) pointMaxRisk = riskImpact;
                }
              }
              totalRisk += pointMaxRisk;
            }
            
            final avgPointRisk = sampledPoints.isNotEmpty ? totalRisk / sampledPoints.length : 0;
            final riskLevel = math.max(0, math.min(100, avgPointRisk.round()));
            
            String label = 'SAFE';
            if (riskLevel >= 76) {
              label = 'CRITICAL';
            } else if (riskLevel >= 56) {
              label = 'HIGH';
            } else if (riskLevel >= 31) {
              label = 'MEDIUM';
            }
            
            final durationMins = (route['duration'] / 60).round();
            final distanceKm = (route['distance'] / 1000).toStringAsFixed(1);
            
            routes.add({
              'points': points,
              'riskLevel': riskLevel,
              'safetyLabel': label,
              'duration': '$durationMins mins',
              'distance': '$distanceKm km',
              'type': i == 0 ? 'Optimal' : i == 1 ? 'Alternative' : 'Safe Corridor',
            });
          }
                    return routes;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getRiskZones() async {
    try {
      final jsonString = await rootBundle.loadString('assets/risk_data.json');
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      return jsonData['zones'] as List<Map<String, dynamic>>;
    } catch (e) {
      return [];
    }
  }
}
