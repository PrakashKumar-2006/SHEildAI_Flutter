import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/services/osrm_service.dart';
import '../../../../core/services/ml_service.dart';
import '../../../../core/models/zone_model.dart';

class RoutesProvider extends ChangeNotifier {
  final MLService _mlService = MLService();
  
  List<OSRMRoute> _routes = [];
  OSRMRoute? _selectedRoute;
  LatLng? _destination;
  String _destinationName = '';
  bool _isLoading = false;
  bool _isEvaluatingSafety = false;
  String _loadingStep = '';
  String? _errorMessage;
  int _selectedRouteIndex = 0;

  List<OSRMRoute> get routes => _routes;
  OSRMRoute? get selectedRoute => _selectedRoute;
  LatLng? get destination => _destination;
  String get destinationName => _destinationName;
  bool get isLoading => _isLoading;
  bool get isEvaluatingSafety => _isEvaluatingSafety;
  String get loadingStep => _loadingStep;
  String? get errorMessage => _errorMessage;
  int get selectedRouteIndex => _selectedRouteIndex;

  void setDestination(String name) {
    _destinationName = name;
    notifyListeners();
  }

  void selectRoute(int index) {
    if (index >= 0 && index < _routes.length) {
      _selectedRouteIndex = index;
      _selectedRoute = _routes[index];
      notifyListeners();
    }
  }

  Future<bool> searchAndCalculateRoutes(
    double originLat,
    double originLon,
    String destinationQuery, {
    int hour = 0,
    int month = 1,
    int isWeekend = 0,
    List<ZoneModel>? zones,
  }) async {
    _isLoading = true;
    _isEvaluatingSafety = false;
    _loadingStep = 'Locating destination...';
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Geocode destination
      final destCoords = await OSRMService.geocodeDestination(
        destinationQuery,
        originLat,
        originLon,
      );

      if (destCoords == null) {
        _errorMessage = 'Could not find destination. Please try a different search term.';
        _isLoading = false;
        _loadingStep = '';
        notifyListeners();
        return false;
      }

      return calculateRoutesFromCoords(
        originLat, 
        originLon, 
        destCoords.latitude, 
        destCoords.longitude,
        hour: hour,
        month: month,
        isWeekend: isWeekend,
        zones: zones,
      );
    } catch (e) {
      _errorMessage = 'Error calculating routes: $e';
      _isLoading = false;
      _loadingStep = '';
      notifyListeners();
      return false;
    }
  }

  Future<bool> calculateRoutesFromCoords(
    double originLat,
    double originLon,
    double destLat,
    double destLon, {
    int hour = 0,
    int month = 1,
    int isWeekend = 0,
    List<ZoneModel>? zones,
  }) async {
    _isLoading = true;
    _isEvaluatingSafety = false;
    _loadingStep = 'Generating route alternatives...';
    _errorMessage = null;
    notifyListeners();

    try {
      _destination = LatLng(destLat, destLon);

      // Step 2: Get routes from OSRM
      final routes = await OSRMService.getRoutes(
        originLat,
        originLon,
        destLat,
        destLon,
        alternatives: 4,
      );

      if (routes.isEmpty) {
        _errorMessage = 'Could not find any routes to this destination.';
        _isLoading = false;
        _loadingStep = '';
        notifyListeners();
        return false;
      }

      // Phase 1: Show initial routes immediately
      _routes = List.from(routes);
      _selectedRouteIndex = 0;
      _selectedRoute = _routes.isNotEmpty ? _routes.first : null;
      _isLoading = false; // Primary loading done
      _isEvaluatingSafety = true;
      _loadingStep = 'Analyzing safety scores (ML models)...';
      notifyListeners();

      // Phase 2: Async Safety Analysis
      _performSafetyAnalysis(
        originLat, originLon, destLat, destLon, 
        hour, month, isWeekend, zones, routes
      ).then((_) {
        _isEvaluatingSafety = false;
        _loadingStep = 'Safety analysis complete!';
        notifyListeners();
      }).catchError((e) {
        debugPrint('[Routes] Safety analysis background error: $e');
        _isEvaluatingSafety = false;
        _loadingStep = 'Safety analysis failed, using fallback.';
        notifyListeners();
      });

      return true;
    } catch (e) {
      _errorMessage = 'Error calculating routes: $e';
      _isLoading = false;
      _isEvaluatingSafety = false;
      _loadingStep = '';
      notifyListeners();
      return false;
    }
  }

  Future<void> _performSafetyAnalysis(
    double originLat, double originLon, double destLat, double destLon,
    int hour, int month, int isWeekend, List<ZoneModel>? zones,
    List<OSRMRoute> originalRoutes,
  ) async {
    // Evaluate routes with ML model for risk scoring
    final routesForML = originalRoutes.map((r) => r.points.map((p) => {
      'lat': p.latitude,
      'lon': p.longitude,
    }).toList()).toList();

    try {
      final mlResult = await _mlService.getSafeRouteV2(
        originLat: originLat,
        originLon: originLon,
        destLat: destLat,
        destLon: destLon,
        hour: hour,
        month: month,
        isWeekend: isWeekend,
        routes: routesForML,
      );

      if (mlResult.containsKey('ranked_routes')) {
        final List<dynamic> rankedIndices = mlResult['ranked_routes'];
        final Map<String, dynamic>? riskScores = mlResult['risk_scores'];
        
        List<OSRMRoute> rankedRoutes = [];
        for (var item in rankedIndices) {
          int idx = -1;
          if (item is int) {
            idx = item;
          } else if (item is Map) idx = item['index'] ?? -1;
          else idx = int.tryParse(item.toString()) ?? -1;

          if (idx >= 0 && idx < originalRoutes.length) {
            final route = originalRoutes[idx];
            if (riskScores != null && riskScores.containsKey(idx.toString())) {
              route.riskScore = (riskScores[idx.toString()] as num).toDouble();
            }
            rankedRoutes.add(route);
          }
        }
        
        if (rankedRoutes.isNotEmpty) {
          rankedRoutes.sort((a, b) {
            int riskCmp = a.riskScore.compareTo(b.riskScore);
            if (riskCmp != 0) return riskCmp;
            return a.distance.compareTo(b.distance);
          });
          _routes = rankedRoutes;
        }
      }
    } catch (e) {
      debugPrint('[Routes] ML evaluation error in background: $e');
      // Fallback: use local zones if ML fails
      if (zones != null && zones.isNotEmpty) {
        _applyLocalZoneSafety(zones);
      }
    }

    // Final sorting and selection update
    _selectedRouteIndex = 0;
    _selectedRoute = _routes.isNotEmpty ? _routes.first : null;
  }

  void _applyLocalZoneSafety(List<ZoneModel> zones) {
    debugPrint('[Routes] Applying local zone safety fallback');
    for (final route in _routes) {
      double totalRisk = 0;
      int pointsChecked = 0;
      for (int i = 0; i < route.points.length; i += 10) {
        pointsChecked++;
        final point = route.points[i];
        for (final zone in zones) {
          final dist = OSRMService.calculateDistance(point.latitude, point.longitude, zone.center.latitude, zone.center.longitude);
          if (dist < (zone.radius * 1000)) {
            totalRisk += zone.riskScore;
            break; 
          }
        }
      }
      route.riskScore = pointsChecked > 0 ? totalRisk / pointsChecked : 0;
    }
    
    _routes.sort((a, b) {
      int riskCmp = a.riskScore.compareTo(b.riskScore);
      if (riskCmp != 0) return riskCmp;
      return a.distance.compareTo(b.distance);
    });
  }

  void clearRoutes() {
    _routes = [];
    _selectedRoute = null;
    _destination = null;
    _destinationName = '';
    _selectedRouteIndex = 0;
    _errorMessage = null;
    _loadingStep = '';
    _isEvaluatingSafety = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

