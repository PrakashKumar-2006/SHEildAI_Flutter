import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/services/osrm_service.dart';
import '../../../../core/services/ml_service.dart';

class RoutesProvider extends ChangeNotifier {
  final MLService _mlService = MLService();
  
  List<OSRMRoute> _routes = [];
  OSRMRoute? _selectedRoute;
  LatLng? _destination;
  String _destinationName = '';
  bool _isLoading = false;
  String? _errorMessage;
  int _selectedRouteIndex = 0;

  List<OSRMRoute> get routes => _routes;
  OSRMRoute? get selectedRoute => _selectedRoute;
  LatLng? get destination => _destination;
  String get destinationName => _destinationName;
  bool get isLoading => _isLoading;
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
  }) async {
    _isLoading = true;
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
        notifyListeners();
        return false;
      }

      _destination = destCoords;

      // Step 2: Get routes from OSRM
      final routes = await OSRMService.getRoutes(
        originLat,
        originLon,
        destCoords.latitude,
        destCoords.longitude,
        alternatives: 4, // Increased to 4
      );

      if (routes.isEmpty) {
        _errorMessage = 'Could not find any routes to this destination.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Step 3: Evaluate routes with ML model for risk scoring
      final routesForML = routes.map((r) => r.points.map((p) => {
        'lat': p.latitude,
        'lon': p.longitude,
      }).toList()).toList();

      try {
        final mlResult = await _mlService.getSafeRouteV2(
          originLat: originLat,
          originLon: originLon,
          destLat: destCoords.latitude,
          destLon: destCoords.longitude,
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
            // ranked_routes might be list of indices or list of maps with index
            int idx = -1;
            if (item is int) idx = item;
            else if (item is Map) idx = item['index'] ?? -1;
            else idx = int.tryParse(item.toString()) ?? -1;

            if (idx >= 0 && idx < routes.length) {
              final route = routes[idx];
              // Attach risk score to the route if available
              if (riskScores != null && riskScores.containsKey(idx.toString())) {
                route.riskScore = (riskScores[idx.toString()] as num).toDouble();
              }
              rankedRoutes.add(route);
            }
          }
          
          if (rankedRoutes.isNotEmpty) {
            // Priority 1: Risk Score (Lowest first) - Always suggest the safest path first
            // Priority 2: Distance (only if risk scores are identical)
            rankedRoutes.sort((a, b) {
              int riskCmp = a.riskScore.compareTo(b.riskScore);
              if (riskCmp != 0) return riskCmp;
              return a.distance.compareTo(b.distance);
            });
            _routes = rankedRoutes;
          } else {
            _routes = routes;
          }
        } else {
          _routes = routes;
        }
      } catch (e) {
        debugPrint('[Routes] ML evaluation error: $e');
        _routes = routes;
      }
      _selectedRouteIndex = 0;
      _selectedRoute = _routes.isNotEmpty ? _routes.first : null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error calculating routes: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearRoutes() {
    _routes = [];
    _selectedRoute = null;
    _destination = null;
    _destinationName = '';
    _selectedRouteIndex = 0;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
