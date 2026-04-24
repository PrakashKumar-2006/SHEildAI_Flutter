import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../services/ml_service.dart';

class MLProvider extends ChangeNotifier {
  final MLService _mlService = MLService();

  // Risk prediction state
  Map<String, dynamic>? _riskPrediction;
  bool _isLoadingRisk = false;
  String? _riskError;
  LatLng? _lastPredictionLocation;

  // Best travel time state
  Map<String, dynamic>? _bestTravelTime;
  bool _isLoadingTravelTime = false;
  String? _travelTimeError;

  // Safe route state
  Map<String, dynamic>? _safeRoutes;
  bool _isLoadingSafeRoutes = false;
  String? _safeRoutesError;

  // Forecast state
  Map<String, dynamic>? _forecast;
  bool _isLoadingForecast = false;
  String? _forecastError;

  // Getters
  Map<String, dynamic>? get riskPrediction => _riskPrediction;
  Map<String, dynamic>? get bestTravelTime => _bestTravelTime;
  Map<String, dynamic>? get safeRoutes => _safeRoutes;
  Map<String, dynamic>? get forecast => _forecast;
  bool get isLoadingRisk => _isLoadingRisk;
  bool get isLoadingTravelTime => _isLoadingTravelTime;
  bool get isLoadingSafeRoutes => _isLoadingSafeRoutes;
  bool get isLoadingForecast => _isLoadingForecast;
  String? get errorMessage => _riskError ?? _travelTimeError ?? _safeRoutesError ?? _forecastError;
  LatLng? get lastPredictionLocation => _lastPredictionLocation;

  // Risk prediction
  Future<void> predictRisk({
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
    _isLoadingRisk = true;
    _riskError = null;
    notifyListeners();

    try {
      _riskPrediction = await _mlService.predictRisk(
        lat: lat,
        lon: lon,
        hour: hour,
        month: month,
        transportMode: transportMode,
        cctv: cctv,
        lighting: lighting,
        internet: internet,
        battery: battery,
        crimeType: crimeType,
        isWeekend: isWeekend,
        weather: weather,
      );
      _lastPredictionLocation = LatLng(lat, lon);
      _isLoadingRisk = false;
      notifyListeners();
    } catch (e) {
      _riskError = e.toString();
      _isLoadingRisk = false;
      notifyListeners();
    }
  }

  // Best travel time
  Future<void> getBestTravelTime({
    required double lat,
    required double lon,
    required int month,
    int isWeekend = 0,
    int topN = 3,
  }) async {
    _isLoadingTravelTime = true;
    _travelTimeError = null;
    notifyListeners();

    try {
      _bestTravelTime = await _mlService.getBestTravelTime(
        lat: lat,
        lon: lon,
        month: month,
        isWeekend: isWeekend,
        topN: topN,
      );
      _isLoadingTravelTime = false;
      notifyListeners();
    } catch (e) {
      _travelTimeError = e.toString();
      _isLoadingTravelTime = false;
      notifyListeners();
    }
  }

  // Safe route V2
  Future<void> getSafeRouteV2({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required int hour,
    required int month,
    int isWeekend = 0,
    required List<List<Map<String, double>>> routes,
  }) async {
    _isLoadingSafeRoutes = true;
    _safeRoutesError = null;
    notifyListeners();

    try {
      _safeRoutes = await _mlService.getSafeRouteV2(
        originLat: originLat,
        originLon: originLon,
        destLat: destLat,
        destLon: destLon,
        hour: hour,
        month: month,
        isWeekend: isWeekend,
        routes: routes,
      );
      _isLoadingSafeRoutes = false;
      notifyListeners();
    } catch (e) {
      _safeRoutesError = e.toString();
      _isLoadingSafeRoutes = false;
      notifyListeners();
    }
  }

  // Forecast
  Future<void> getForecast({
    required double lat,
    required double lon,
    required int currentHour,
    required int month,
    int isWeekend = 0,
  }) async {
    _isLoadingForecast = true;
    _forecastError = null;
    notifyListeners();

    try {
      _forecast = await _mlService.getForecast(
        lat: lat,
        lon: lon,
        currentHour: currentHour,
        month: month,
        isWeekend: isWeekend,
      );
      _isLoadingForecast = false;
      notifyListeners();
    } catch (e) {
      _forecastError = e.toString();
      _isLoadingForecast = false;
      notifyListeners();
    }
  }

  // Clear errors
  void clearRiskError() {
    _riskError = null;
    notifyListeners();
  }

  void clearTravelTimeError() {
    _travelTimeError = null;
    notifyListeners();
  }

  void clearSafeRoutesError() {
    _safeRoutesError = null;
    notifyListeners();
  }

  void clearForecastError() {
    _forecastError = null;
    notifyListeners();
  }
}
