import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../providers/providers.dart';
import '../core/app_theme.dart';
import '../widgets/notification_bell_popup.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final TextEditingController _fromController = TextEditingController(text: 'Current Location');
  final TextEditingController _toController = TextEditingController();
  final MapController _mapController = MapController();
  
  bool _isLoading = false;
  bool _isNavigating = false;
  bool _newRoutesFound = false;
  int _selectedRoute = 0;
  List<Map<String, dynamic>> _routes = [];
  LatLng? _destCoords;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  double _getDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
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

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _fetchRoutes(String destText, bool isAutoReroute) async {
    if (destText.trim().isEmpty) return;
    final safety = context.read<SafetyProvider>();
    final lat = safety.latitude;
    final lon = safety.longitude;

    setState(() => _isLoading = true);

    try {
      // Nominatim Geocoding
      final geoUrl = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(destText)}&format=json&limit=1&lat=$lat&lon=$lon');
      final geoRes = await http.get(geoUrl, headers: {'User-Agent': 'SHEild AI/1.0'});
      final geoData = jsonDecode(geoRes.body) as List;

      if (geoData.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final destLat = double.parse(geoData[0]['lat']);
      final destLon = double.parse(geoData[0]['lon']);
      
      if (mounted) {
        setState(() => _destCoords = LatLng(destLat, destLon));
      }

      // OSRM Routing
      final osrmUrl = Uri.parse('https://router.project-osrm.org/route/v1/driving/$lon,$lat;$destLon,$destLat?overview=full&geometries=polyline&alternatives=3');
      final osrmRes = await http.get(osrmUrl);
      final osrmData = jsonDecode(osrmRes.body);

      if (osrmData['code'] != 'Ok') {
        setState(() => _isLoading = false);
        return;
      }

      final List<Map<String, dynamic>> evaluatedRoutes = [];
      final routesList = osrmData['routes'] as List;

      for (int i = 0; i < routesList.length; i++) {
        final r = routesList[i];
        final points = _decodePolyline(r['geometry']);
        
        // Mock Risk Calculation for UI
        final riskLevel = i == 0 ? 20 : (i == 1 ? 45 : 78);
        String label = 'SAFE';
        if (riskLevel >= 76) label = 'CRITICAL';
        else if (riskLevel >= 56) label = 'HIGH';
        else if (riskLevel >= 31) label = 'MEDIUM';

        final durationMins = (r['duration'] / 60).round();
        final distanceKm = (r['distance'] / 1000).toStringAsFixed(1);

        evaluatedRoutes.add({
          'points': points,
          'riskLevel': riskLevel,
          'safetyLabel': label,
          'duration': '$durationMins mins',
          'distance': '$distanceKm km',
          'type': i == 0 ? 'Optimal' : i == 1 ? 'Alternative' : 'Safe Corridor',
          'isML': false,
          'travelAdvice': riskLevel < 30 ? 'Safest route detected.' : (riskLevel < 60 ? 'Proceed with caution.' : 'Avoid if possible.'),
        });
      }

      evaluatedRoutes.sort((a, b) => (a['riskLevel'] as int).compareTo(b['riskLevel'] as int));

      if (mounted) {
        setState(() {
          _routes = evaluatedRoutes.take(4).toList();
          _isLoading = false;
          if (isAutoReroute) {
            _newRoutesFound = true;
          } else {
            _selectedRoute = 0;
            _isNavigating = false;
          }
        });

        // Fit bounds
        if (_destCoords != null) {
          final bounds = LatLngBounds.fromPoints([LatLng(lat, lon), _destCoords!]);
          _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();
    final safety = context.watch<SafetyProvider>();
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: theme.background,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : null,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(18)),
                      child: Icon(Icons.person_rounded, color: theme.textPrimary, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'SHEild AI',
                    style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                  const Spacer(),
                  NotificationBellPopup(iconColor: theme.textPrimary),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Route Planner',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: theme.textPrimary),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Route planner card
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0, top: 0, bottom: 0,
                            width: 4,
                            child: Container(color: theme.accent),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              children: [
                                _buildRouteInput(
                                  controller: _fromController,
                                  hint: lang.t('current_location'),
                                  icon: Icons.my_location_rounded,
                                  iconColor: theme.accent,
                                  theme: theme,
                                ),
                                Container(
                                  height: 1,
                                  color: theme.border,
                                  margin: const EdgeInsets.only(left: 30),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildRouteInput(
                                        controller: _toController,
                                        hint: lang.t('where_heading'),
                                        icon: Icons.location_on_rounded,
                                        iconColor: theme.accent,
                                        theme: theme,
                                        onSubmit: (v) => _fetchRoutes(v, false),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _fetchRoutes(_toController.text, false),
                                      child: Container(
                                        width: 36, height: 36,
                                        margin: const EdgeInsets.only(left: 6),
                                        decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(10)),
                                        child: const Icon(Icons.search_rounded, color: Colors.white, size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Map View
                    SizedBox(
                      height: _isNavigating ? MediaQuery.of(context).size.height * 0.6 : 450,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: LatLng(safety.latitude, safety.longitude),
                              initialZoom: 14,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                subdomains: const ['a', 'b', 'c'],
                                userAgentPackageName: 'com.shieldai.app',
                              ),
                              if (_routes.isNotEmpty && _routes.length > _selectedRoute)
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: _routes[_selectedRoute]['points'],
                                      strokeWidth: 6,
                                      color: (_routes[_selectedRoute]['riskLevel'] as int) <= 25 ? const Color(0xFF43A047) :
                                             (_routes[_selectedRoute]['riskLevel'] as int) <= 62 ? const Color(0xFFFFD700) :
                                             (_routes[_selectedRoute]['riskLevel'] as int) <= 75 ? const Color(0xFFFF4D4D) : const Color(0xFF8B0000),
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  // User marker
                                  Marker(
                                    point: LatLng(safety.latitude, safety.longitude),
                                    width: 40, height: 40,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF1976D2).withOpacity(0.2),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 16, height: 16,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF1976D2),
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Destination marker
                                  if (_destCoords != null)
                                    Marker(
                                      point: _destCoords!,
                                      width: 32, height: 32,
                                      alignment: Alignment.topCenter,
                                      child: const Icon(Icons.location_on, color: Color(0xFFE91E63), size: 32),
                                    ),
                                  // Risk markers
                                  if (_routes.isNotEmpty && _routes.length > _selectedRoute)
                                    ..._routes[_selectedRoute]['points']
                                        .asMap()
                                        .entries
                                        .where((e) => e.key % 20 == 0)
                                        .map((e) => Marker(
                                              point: e.value,
                                              width: 16, height: 16,
                                              child: const Icon(Icons.warning_rounded, color: Color(0xFFFF4D4D), size: 16),
                                            ))
                                ],
                              ),
                            ],
                          ),
                          if (_isNavigating)
                            Positioned(
                              top: 0, left: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D1B6E),
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('HEADING TO', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.w700)),
                                          Text(_toController.text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() { _isNavigating = false; _newRoutesFound = false; }),
                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (_newRoutesFound && _isNavigating)
                            Positioned(
                              top: 80, left: 16, right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFF9800)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_rounded, color: Color(0xFFFFD700), size: 20),
                                    const SizedBox(width: 8),
                                    const Expanded(child: Text('High risk detected ahead', style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w700, fontSize: 13))),
                                    ElevatedButton(
                                      onPressed: () => setState(() { _isNavigating = false; _newRoutesFound = false; }),
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), visualDensity: VisualDensity.compact),
                                      child: const Text('View Paths', style: TextStyle(color: Colors.white, fontSize: 11)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Routes Section
                    if (!_isNavigating)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (_isLoading)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(14)),
                                child: Column(
                                  children: [
                                    Icon(Icons.sync_rounded, color: theme.accent, size: 40),
                                    const SizedBox(height: 12),
                                    Text(lang.t('analyzing'), style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              )
                            else if (_routes.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(14)),
                                child: Column(
                                  children: [
                                    Icon(Icons.search_rounded, color: theme.textSecondary, size: 40),
                                    const SizedBox(height: 12),
                                    Text(lang.t('enter_destination'), style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              )
                            else
                              ..._routes.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final r = entry.value;
                                final isSel = _selectedRoute == idx;
                                final risk = r['riskLevel'] as int;
                                final isSafe = risk <= 30;
                                final isMed = risk <= 55;
                                
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedRoute = idx),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: theme.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: isSel ? (isSafe ? const Color(0xFF43A047) : isMed ? const Color(0xFFFFD700) : const Color(0xFFFF4D4D)) : Colors.transparent, width: 2),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 44, height: 44,
                                          decoration: BoxDecoration(
                                            color: isDark ? (isSafe ? const Color(0xFF064e3b) : const Color(0xFF78350f)) : (isSafe ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0)),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(isSafe ? Icons.shield_rounded : Icons.warning_rounded, color: isSafe ? (isDark ? const Color(0xFF34d399) : const Color(0xFF2E7D32)) : (isDark ? const Color(0xFFfbbf24) : const Color(0xFFFF9800))),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(idx == 0 ? lang.t('safest_path') : '${lang.t('alternative')} $idx', style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                                              const SizedBox(height: 3),
                                              Text('${r['duration']} • ${r['distance']}', style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                                              if (r['travelAdvice'] != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text('💡 ${r['travelAdvice']}', style: TextStyle(color: isSafe ? (isDark ? const Color(0xFF34d399) : const Color(0xFF2E7D32)) : theme.textSecondary, fontSize: 10, fontStyle: FontStyle.italic)),
                                                ),
                                              Container(
                                                margin: const EdgeInsets.only(top: 8),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isDark ? (isSafe ? const Color(0xFF064e3b) : isMed ? const Color(0xFF422006) : const Color(0xFF7f1d1d)) : (isSafe ? const Color(0xFFE8F5E9) : isMed ? const Color(0xFFFFFDE7) : const Color(0xFFFFF3E0)),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  isSafe ? lang.t('optimized_safety') : isMed ? lang.t('moderate_risk') : lang.t('high_risk_zone'),
                                                  style: TextStyle(color: isDark ? (isSafe ? const Color(0xFF34d399) : isMed ? const Color(0xFFfbbf24) : const Color(0xFFf87171)) : (isSafe ? const Color(0xFF2E7D32) : isMed ? const Color(0xFF854d0e) : const Color(0xFFea580c)), fontSize: 10, fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          children: [
                                            Text('${r['riskLevel']}%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isSafe ? const Color(0xFF43A047) : isMed ? const Color(0xFFFFD700) : const Color(0xFFFF4D4D))),
                                            Text(lang.t('danger_level'), style: TextStyle(fontSize: 9, color: theme.textSecondary, fontWeight: FontWeight.w600)),
                                            if (isSel)
                                              GestureDetector(
                                                onTap: () => setState(() => _isNavigating = true),
                                                child: Container(
                                                  margin: const EdgeInsets.only(top: 10),
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  decoration: BoxDecoration(color: const Color(0xFF0D1B6E), borderRadius: BorderRadius.circular(8)),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 16),
                                                      const SizedBox(width: 4),
                                                      Text(lang.t('navigate'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Nav bottom stats
            if (_isNavigating && _routes.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0f172a) : Colors.white,
                  border: Border(top: BorderSide(color: theme.border)),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavStat(lang.t('time').toUpperCase(), _routes[_selectedRoute]['duration'], theme.textPrimary),
                    Container(width: 1, height: 30, color: theme.border),
                    _buildNavStat(lang.t('dist').toUpperCase(), _routes[_selectedRoute]['distance'], theme.textPrimary),
                    Container(width: 1, height: 30, color: theme.border),
                    _buildNavStat(lang.t('risk').toUpperCase(), '${_routes[_selectedRoute]['riskLevel']}%', (_routes[_selectedRoute]['riskLevel'] as int) > 30 ? const Color(0xFFd32f2f) : const Color(0xFF2e7d32)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavStat(String label, String value, Color valColor) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valColor, fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildRouteInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required ThemeProvider theme,
    Function(String)? onSubmit,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            style: TextStyle(color: theme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: theme.textSecondary),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: onSubmit,
            textInputAction: onSubmit != null ? TextInputAction.search : TextInputAction.next,
          ),
        ),
      ],
    );
  }
}
