import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

// ─────────────────────────────────────────────
//  CONFIG — tune all thresholds in one place
// ─────────────────────────────────────────────
class _Cfg {
  // OSM
  static const double scanRadius        = 1200.0; // metres
  static const int    osmTimeoutSec     = 12;
  static const int    maxPlacesDisplay  = 25;

  // POI weights
  static const double weightPolice      = 18.0;
  static const double weightHospital    = 14.0;
  static const double weightShopOrFood  = 8.0;
  static const double weightDefault     = 5.0;
  static const double policeNearbyMetres = 400.0;

  // Safety-score → risk mapping
  static const double safetyHighThreshold = 40.0;
  static const double safetyMidThreshold  = 15.0;
  static const double baseRiskLow         = 15.0;
  static const double baseRiskMid         = 30.0;
  static const double baseRiskHigh        = 50.0;
  static const double policeOverrideRisk  = 10.0;
  static const double maxRiskScore        = 100.0;

  // Time-of-day risk multipliers
  static const double eveningStartHour    = 18.0; // 6 PM
  static const double eveningEndHour      = 22.0; // 10 PM
  static const double eveningMaxMult      = 2.0;
  static const double nightMult           = 2.5;  // 10 PM – 5 AM
  static const double nightEndHour        = 5.0;

  // Community report penalties
  static const double penaltyHigh         = 25.0;
  static const double penaltyMedium       = 12.0;
  static const double penaltyLow          = 5.0;
  static const double communityHighThresh = 20.0;

  // Cache
  static const Duration cacheTtl         = Duration(minutes: 8);
  static const double   cacheTileDegrees = 0.005; // ~500 m tile
}

// ─────────────────────────────────────────────
//  RESULT MODEL
// ─────────────────────────────────────────────
class CrowdDensityResult {
  final double riskScore;          // 0–100 (higher = more risky)
  final String densityLevel;       // human-readable label
  final int    poiCount;
  final List<String> detectedPlaces;
  final bool   hasRecentCommunityAlerts;
  final String? errorMessage;

  const CrowdDensityResult({
    required this.riskScore,
    required this.densityLevel,
    required this.poiCount,
    required this.detectedPlaces,
    this.hasRecentCommunityAlerts = false,
    this.errorMessage,
  });

  /// Convenience: normalised 0–1 value for UI progress bars.
  double get normalised => riskScore / _Cfg.maxRiskScore;

  @override
  String toString() =>
      'CrowdDensityResult(score: $riskScore, level: $densityLevel, '
      'pois: $poiCount, alerts: $hasRecentCommunityAlerts)';
}

// ─────────────────────────────────────────────
//  SIMPLE IN-MEMORY CACHE ENTRY
// ─────────────────────────────────────────────
class _CacheEntry {
  final CrowdDensityResult result;
  final DateTime expiresAt;
  _CacheEntry(this.result) : expiresAt = DateTime.now().add(_Cfg.cacheTtl);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

// ─────────────────────────────────────────────
//  SERVICE
// ─────────────────────────────────────────────
class CrowdDensityService {
  final http.Client _client;

  CrowdDensityService({http.Client? client})
      : _client = client ?? http.Client();

  // ── Overpass mirror list ──────────────────
  static const List<String> _servers = [
    'https://overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  // ── Tile-keyed cache ─────────────────────
  final Map<String, _CacheEntry> _cache = {};

  String _tileKey(double lat, double lon) {
    final tLat = (lat / _Cfg.cacheTileDegrees).floor();
    final tLon = (lon / _Cfg.cacheTileDegrees).floor();
    return '$tLat:$tLon';
  }

  // ─────────────────────────────────────────
  //  PUBLIC ENTRY POINT
  // ─────────────────────────────────────────
  Future<CrowdDensityResult> getDensityScore(double lat, double lon) async {
    // 1. Cache hit?
    final key   = _tileKey(lat, lon);
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      debugPrint('[CrowdDensity] Cache hit for $key');
      return entry.result;
    }

    // 2. Fetch OSM + community reports in parallel
    final results = await Future.wait([
      _fetchOsmResult(lat, lon),
      _fetchCommunityPenalty(lat, lon),
    ]);

    final osmResult       = results[0] as CrowdDensityResult;
    final communityResult = results[1] as _CommunityPenalty;

    // 3. Merge
    final final_ = _merge(osmResult, communityResult);

    // 4. Store in cache
    _cache[key] = _CacheEntry(final_);
    return final_;
  }

  /// Dispose the underlying HTTP client when the service is no longer needed.
  void dispose() => _client.close();

  // ─────────────────────────────────────────
  //  OSM FETCH  (races all servers, first SUCCESS wins)
  // ─────────────────────────────────────────
  Future<CrowdDensityResult> _fetchOsmResult(double lat, double lon) async {
    final query = _buildQuery(lat, lon);

    // Race all mirrors – fastest SUCCESSFUL response wins
    final completer = Completer<http.Response>();
    int failedCount = 0;
    
    for (final url in _servers) {
      _client.post(
        Uri.parse(url),
        headers: {'User-Agent': 'SHEildAI-SafetyApp/1.2'},
        body: {'data': query},
      ).timeout(Duration(seconds: _Cfg.osmTimeoutSec)).then((res) {
        if (res.statusCode == 200 && !completer.isCompleted) {
          completer.complete(res);
        } else {
          throw Exception('Status ${res.statusCode}');
        }
      }).catchError((e) {
        failedCount++;
        if (failedCount == _servers.length && !completer.isCompleted) {
          completer.completeError(Exception('All OSM mirrors failed'));
        }
      });
    }

    try {
      final response = await completer.future;
      final data     = json.decode(response.body) as Map<String, dynamic>;
      final elements = (data['elements'] as List?) ?? [];
      return _calculateRiskScore(elements, lat, lon);
    } catch (e) {
      debugPrint('[CrowdDensity] All OSM servers failed: $e');
      // Graceful degradation: align with the core philosophy that 'unknown/isolated = risky'.
      final timeMultiplier = _timeRiskMultiplier();
      final double fallbackRisk = (50.0 * timeMultiplier).clamp(0.0, 100.0);
      
      final hour = _localHour();
      final level = (hour > 20 || hour < 5.0) 
          ? 'Isolated (Offline Mode)' 
          : 'Quiet Area (Offline Mode)';

      return CrowdDensityResult(
        riskScore: fallbackRisk,
        densityLevel: level,
        poiCount: 0,
        detectedPlaces: [],
        errorMessage: 'OSM unavailable',
      );
    }
  }

  // ─────────────────────────────────────────
  //  COMMUNITY PENALTY FETCH
  // ─────────────────────────────────────────
  Future<_CommunityPenalty> _fetchCommunityPenalty(
      double lat, double lon) async {
    try {
      final reports =
          await ApiService.fetchNearbyCommunityReports(lat, lon, 1.0);
      if (reports == null || reports.isEmpty) return const _CommunityPenalty();

      double penalty = 0;
      for (final report in reports) {
        final sev = (report['severity'] as String?)?.toLowerCase() ?? 'low';
        if (sev == 'high')        penalty += _Cfg.penaltyHigh;
        else if (sev == 'medium') penalty += _Cfg.penaltyMedium;
        else                      penalty += _Cfg.penaltyLow;
      }
      return _CommunityPenalty(penalty: penalty, reportCount: reports.length);
    } catch (e) {
      debugPrint('[CrowdDensity] Community sync failed: $e');
      return const _CommunityPenalty();
    }
  }

  // ─────────────────────────────────────────
  //  MERGE OSM + COMMUNITY
  // ─────────────────────────────────────────
  CrowdDensityResult _merge(
      CrowdDensityResult osm, _CommunityPenalty community) {
    if (community.penalty <= 0) return osm;

    final newScore =
        (osm.riskScore + community.penalty).clamp(0.0, _Cfg.maxRiskScore);

    final newLevel = community.penalty > _Cfg.communityHighThresh
        ? 'High Risk (Community Alerts)'
        : 'Caution (Recent Reports)';

    return CrowdDensityResult(
      riskScore: newScore,
      densityLevel: newLevel,
      poiCount: osm.poiCount,
      detectedPlaces: osm.detectedPlaces,
      hasRecentCommunityAlerts: true,
    );
  }

  // ─────────────────────────────────────────
  //  RISK SCORE CALCULATION
  // ─────────────────────────────────────────
  CrowdDensityResult _calculateRiskScore(
      List<dynamic> elements, double userLat, double userLon) {
    double     safetyScore    = 0;
    bool       hasPoliceNearby = false;
    final      Set<String> placesSet = {};

    for (final element in elements) {
      final tags   = (element['tags']   as Map?)              ?? {};
      final center = (element['center'] as Map?) ??
          {'lat': element['lat'], 'lon': element['lon']};

      final eLat = (center['lat'] as num?)?.toDouble();
      final eLon = (center['lon'] as num?)?.toDouble();
      if (eLat == null || eLon == null) continue;

      final distMetres =
          _haversineKm(userLat, userLon, eLat, eLon) * 1000;
      // Linear decay: full weight at 0m, zero at scanRadius
      final decay = (1.0 - (distMetres / _Cfg.scanRadius)).clamp(0.1, 1.0);

      final name = (tags['name']     as String?) ??
                   (tags['amenity']  as String?) ??
                   (tags['shop']     as String?) ??
                   (tags['leisure']  as String?);
      if (name == null) continue;

      placesSet.add(name);

      double weight = _Cfg.weightDefault;
      if (tags['amenity'] == 'police') {
        weight = _Cfg.weightPolice;
        if (distMetres < _Cfg.policeNearbyMetres) hasPoliceNearby = true;
      } else if (tags['amenity'] == 'hospital') {
        weight = _Cfg.weightHospital;
      } else if (tags['shop'] != null ||
          tags['amenity'] == 'restaurant' ||
          tags['amenity'] == 'cafe') {
        weight = _Cfg.weightShopOrFood;
      }
      safetyScore += weight * decay;
    }

    final timeMultiplier = _timeRiskMultiplier();
    double riskScore;
    String level;

    if (hasPoliceNearby) {
      riskScore = _Cfg.policeOverrideRisk;
      level     = 'Very Safe (Police Nearby)';
    } else {
      // SMOOTH INTERPOLATION to avoid the 15% -> 50% jumps
      // Logic:
      // Safety Score >= 40 (Active) -> 15% base risk
      // Safety Score == 15 (Moderate) -> 30% base risk
      // Safety Score <= 0 (Isolated) -> 50% base risk
      
      double baseRisk;
      if (safetyScore >= _Cfg.safetyHighThreshold) {
        // Linear improvement for very active areas: 40 (15%) -> 80 (10%)
        final t = ((safetyScore - 40) / 40).clamp(0.0, 1.0);
        baseRisk = 15.0 - (t * 5.0);
        level = 'Active Area';
      } else if (safetyScore >= _Cfg.safetyMidThreshold) {
        // Interpolate between Mid (30%) and High (15%)
        final t = ((safetyScore - 15) / (40 - 15)).clamp(0.0, 1.0);
        baseRisk = 30.0 - (t * (30.0 - 15.0));
        level = 'Moderate Activity';
      } else {
        // Interpolate between Isolated (50%) and Mid (30%)
        final t = (safetyScore / 15.0).clamp(0.0, 1.0);
        baseRisk = 50.0 - (t * (50.0 - 30.0));
        final hour = _localHour();
        level = (hour > 20 || hour < _Cfg.nightEndHour)
            ? 'Isolated (High Risk)'
            : 'Quiet Area';
      }
      
      riskScore = (baseRisk * timeMultiplier).clamp(0.0, _Cfg.maxRiskScore);
    }

    // Cap display list so the UI is not flooded
    final places = placesSet.take(_Cfg.maxPlacesDisplay).toList();

    return CrowdDensityResult(
      riskScore: riskScore,
      densityLevel: level,
      poiCount: elements.length,
      detectedPlaces: places,
    );
  }

  // ─────────────────────────────────────────
  //  TIME RISK MULTIPLIER  (device local time)
  // ─────────────────────────────────────────
  /// Returns a multiplier ≥ 1.0.
  /// NOTE: uses device local time. For accuracy across timezones,
  /// pass a UTC offset derived from the coordinates (future improvement).
  double _timeRiskMultiplier() {
    final hour = _localHour();

    if (hour >= _Cfg.eveningStartHour && hour <= _Cfg.eveningEndHour) {
      // Ramps from 1.0 at 6 PM → 2.0 at 10 PM
      final t = (hour - _Cfg.eveningStartHour) /
          (_Cfg.eveningEndHour - _Cfg.eveningStartHour);
      return 1.0 + t * (_Cfg.eveningMaxMult - 1.0);
    }
    if (hour > _Cfg.eveningEndHour || hour < _Cfg.nightEndHour) {
      return _Cfg.nightMult;
    }
    return 1.0;
  }

  double _localHour() {
    final now = DateTime.now();
    return now.hour + (now.minute / 60.0);
  }

  // ─────────────────────────────────────────
  //  OVERPASS QUERY BUILDER
  // ─────────────────────────────────────────
  String _buildQuery(double lat, double lon) => '''
[out:json][timeout:25];
(
  nwr(around:${_Cfg.scanRadius},$lat,$lon)["amenity"~"market_place|bus_station|university|hospital|police|pharmacy|restaurant|cafe"];
  nwr(around:${_Cfg.scanRadius},$lat,$lon)["shop"];
  nwr(around:${_Cfg.scanRadius},$lat,$lon)["public_transport"~"station|stop_position"];
  nwr(around:${_Cfg.scanRadius},$lat,$lon)["leisure"~"park|stadium|sports_centre"];
);
out center tags;
''';

  // ─────────────────────────────────────────
  //  HAVERSINE  (no external dependency)
  // ─────────────────────────────────────────
  double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r   = 6371.0; // Earth radius in km
    const rad = pi / 180.0;
    final dLat = (lat2 - lat1) * rad;
    final dLon = (lon2 - lon1) * rad;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * rad) * cos(lat2 * rad) *
            sin(dLon / 2) * sin(dLon / 2);
    return 2 * r * asin(sqrt(a));
  }
}

// ─────────────────────────────────────────────
//  INTERNAL HELPER — community penalty data
// ─────────────────────────────────────────────
class _CommunityPenalty {
  final double penalty;
  final int    reportCount;
  const _CommunityPenalty({this.penalty = 0, this.reportCount = 0});
}