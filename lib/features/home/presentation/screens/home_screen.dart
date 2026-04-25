import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:ionicons/ionicons.dart';
import '../providers/home_provider.dart';
import '../../../../features/sos/presentation/screens/sos_screen.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../voice/presentation/providers/voice_provider.dart';
import '../../../sos/presentation/providers/sos_provider.dart';
import '../../../../core/providers/ml_provider.dart';
import '../../../../core/services/zone_service.dart';
import '../../../../providers/providers.dart' show SafetyProvider;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final locationProvider = context.watch<LocationProvider>();
    final sosProvider = context.watch<SOSProvider>();
    final voiceProvider = context.watch<VoiceProvider>();
    final mlProvider = context.watch<MLProvider>();
    final currentLocation = locationProvider.currentLocation;
    final currentLat = currentLocation?.latitude;
    final currentLng = currentLocation?.longitude;
    final hasLocation = currentLat != null && currentLng != null;
    
    // Animate map when location is first fetched
    if (hasLocation && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(currentLat, currentLng)),
      );
    }
    final now = DateTime.now();
    
    // Auto-predict risk on first load
    if (hasLocation && mlProvider.riskPrediction == null && !mlProvider.isLoadingRisk) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mlProvider.predictRisk(
          lat: currentLat!,
          lon: currentLng!,
          hour: now.hour,
          month: now.month,
          isWeekend: now.weekday >= 5 ? 1 : 0,
        );
      });
    }
    
    // Auto-get best travel time on first load
    if (hasLocation && mlProvider.bestTravelTime == null && !mlProvider.isLoadingTravelTime) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mlProvider.getBestTravelTime(
          lat: currentLat!,
          lon: currentLng!,
          month: now.month,
          isWeekend: now.weekday >= 5 ? 1 : 0,
          topN: 3,
        );
      });
    }

    // Auto-get forecast on first load
    if (hasLocation && mlProvider.forecast == null && !mlProvider.isLoadingForecast) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mlProvider.getForecast(
          lat: currentLat!,
          lon: currentLng!,
          currentHour: now.hour,
          month: now.month,
          isWeekend: now.weekday >= 5 ? 1 : 0,
        );
      });
    }

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Consumer<HomeProvider>(
          builder: (context, homeProvider, child) {
            return Column(
              children: [
                // Header
                _buildHeader(context, homeProvider),
                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Safety Indicator Circle
                        _buildSafetyCard(context, homeProvider, locationProvider),
                        const SizedBox(height: 20),
                        // Safety Intelligence Section
                        _buildIntelligenceSection(context, homeProvider),
                        const SizedBox(height: 14),
                        // Search Bar
                        _buildSearchCard(context),
                        const SizedBox(height: 14),
                        // Best Travel Time
                        _buildBestTravelTimeCard(context, mlProvider),
                        const SizedBox(height: 14),
                        // Voice Card
                        _buildVoiceCard(context, voiceProvider),
                        const SizedBox(height: 14),
                        // Map Card
                        _buildMapCard(context, locationProvider),
                        const SizedBox(height: 14),
                        // SOS Button
                        _buildSOSButton(context, sosProvider),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SOSScreen()),
          );
        },
        backgroundColor: Colors.red,
        icon: const Icon(Ionicons.alert_circle, color: Colors.white),
        label: const Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, HomeProvider homeProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE3E6F0),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Ionicons.person, size: 20),
                  onPressed: () => Navigator.pushNamed(context, '/profile'),
                  color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'SHEild AI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Ionicons.notifications_outline, size: 20),
              onPressed: () {},
              color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCard(BuildContext context, HomeProvider homeProvider, LocationProvider locationProvider) {
    final mlProvider = context.watch<MLProvider>();
    final zoneService = context.watch<ZoneService>();
    final riskPrediction = mlProvider.riskPrediction;
    final currentZone = zoneService.currentZone;
    
    // Use zone-based risk if available, otherwise use ML prediction
    int riskScore;
    String riskLevel;
    String riskColor;
    
    if (!zoneService.isDataAvailable) {
      // Data not available within 10km
      riskScore = 0;
      riskLevel = 'N/A';
      riskColor = '#9E9E9E';
    } else if (currentZone != null) {
      // Use zone-based risk
      riskScore = currentZone.riskScore;
      riskLevel = currentZone.zoneLabel;
      riskColor = currentZone.zoneColor;
    } else if (riskPrediction != null) {
      // Use ML prediction
      riskScore = riskPrediction['risk_score']?.toInt() ?? homeProvider.currentRiskLevel;
      riskLevel = riskPrediction['risk_level']?.toString() ?? homeProvider.currentRiskLevel.toString();
      riskColor = riskPrediction['color'] ?? '#43A047';
    } else {
      // Fallback
      riskScore = int.tryParse(homeProvider.currentRiskLevel.toString()) ?? 0;
      riskLevel = homeProvider.currentRiskLevel.toString();
      riskColor = '#43A047';
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Safety Circle
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF43A047).withValues(alpha: 0.1),
            ),
            child: Center(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isDarkMode 
                      ? Colors.white.withValues(alpha: 0.05) 
                      : Colors.white.withValues(alpha: 0.4),
                ),
                child: Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          riskLevel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _parseColor(riskColor),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$riskScore',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w800,
                                color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                              ),
                            ),
                            Text(
                              '%',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF43A047),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Ionicons.shield_checkmark,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  'I AM SAFE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Location Text
          Text(
            homeProvider.currentLocation,
            style: TextStyle(
              fontSize: 14,
              color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntelligenceSection(BuildContext context, HomeProvider homeProvider) {
    final mlProvider = context.watch<MLProvider>();
    final forecastData = mlProvider.forecast;
    final bestTime = mlProvider.bestTravelTime;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Ionicons.analytics_outline, size: 18, color: Color(0xFF0D1B6E)),
              const SizedBox(width: 8),
              Text(
                'SAFETY INTELLIGENCE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Forecast
                if (mlProvider.isLoadingForecast)
                  const Center(child: CircularProgressIndicator(strokeWidth: 2))
                else if (forecastData != null && forecastData['forecast'] != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: (forecastData['forecast'] as List).take(3).map((item) {
                      final hour = item['hour'] as int;
                      final risk = (item['risk_score'] as num).toInt();
                      return Column(
                        children: [
                          Text(
                            '$hour:00',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: risk > 70 
                                  ? const Color(0xFF8B0000) 
                                  : risk > 40 
                                      ? const Color(0xFFFFD700) 
                                      : const Color(0xFF43A047),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$risk%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: risk > 70 
                                  ? const Color(0xFF8B0000) 
                                  : risk > 40 
                                      ? const Color(0xFFFFD700) 
                                      : const Color(0xFF43A047),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  )
                else
                  const Text('Forecast unavailable'),
                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFF0F0F0),
                ),
                const SizedBox(height: 12),
                // Travel Advice
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color(0xFF064e3b) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Ionicons.time_outline, size: 16, color: Color(0xFF43A047)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mlProvider.isLoadingTravelTime 
                              ? 'Loading advice...'
                              : (bestTime != null && bestTime['safest_hours'] != null && (bestTime['safest_hours'] as List).isNotEmpty)
                                  ? 'Safest travel window: ${(bestTime['safest_hours'] as List)[0]['hour']}:00'
                                  : 'Stay vigilant while traveling.',
                          style: TextStyle(
                            fontSize: 13,
                            color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/routes'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: const Icon(
                Ionicons.navigate_outline,
                size: 20,
                color: Color(0xFF64748B),
              ),
            ),
            Expanded(
              child: Text(
                'Where are you heading?',
                style: TextStyle(
                  fontSize: 14,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1B6E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Safe Route',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestTravelTimeCard(BuildContext context, MLProvider mlProvider) {
    final bestTravelTime = mlProvider.bestTravelTime;
    
    if (bestTravelTime == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Ionicons.time,
                size: 20,
                color: Color(0xFF1976D2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Best Travel Time',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                    ),
                  ),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    final safestHours = bestTravelTime['safest_hours'] as List?;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Ionicons.time,
                  size: 20,
                  color: Color(0xFF1976D2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Best Travel Time',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                      ),
                    ),
                    Text(
                      'Safest hours to travel today',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (safestHours != null && safestHours.isNotEmpty)
            ...safestHours.take(3).map((hourData) {
              final hour = hourData['hour'] as int?;
              final riskScore = hourData['risk_score']?.toDouble() ?? 0.0;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Ionicons.time_outline,
                          size: 16,
                          color: const Color(0xFF1976D2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${hour ?? 0}:00',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Ionicons.shield_checkmark,
                          size: 14,
                          color: const Color(0xFF43A047),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(riskScore * 100).toInt()}% Safe',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF43A047),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            })
          else
            Text(
              'No travel time data available',
              style: TextStyle(
                fontSize: 12,
                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceCard(BuildContext context, VoiceProvider voiceProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: voiceProvider.isListening 
              ? (_isDarkMode ? const Color(0xFFef4444) : const Color(0xFFdc2626))
              : (_isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: voiceProvider.isListening
                  ? (_isDarkMode ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF1F5F9))
                  : (_isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              voiceProvider.isListening ? Ionicons.mic : Ionicons.mic_off_outline,
              size: 20,
              color: voiceProvider.isListening 
                  ? const Color(0xFFef4444) 
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Detection',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  voiceProvider.isListening 
                      ? '🔴 Listening for "help"…' 
                      : 'Say "help" to trigger SOS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // Switch
          Switch(
            value: voiceProvider.isListening,
            onChanged: (value) => voiceProvider.toggleVoiceTrigger(value),
            activeTrackColor: const Color(0xFFdc2626),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(BuildContext context, LocationProvider locationProvider) {
    final zoneService = context.watch<ZoneService>();
    final currentLocation = locationProvider.currentLocation;
    final currentLat = currentLocation?.latitude ?? 22.7196;
    final currentLng = currentLocation?.longitude ?? 75.8577;
    final zones = zoneService.zones;
    final hasLocation = currentLocation != null;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 250,
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: hasLocation ? GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(currentLat!, currentLng!),
            zoom: 15.0,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            // Immediate animation if location already exists
            if (currentLat != 22.7196 || currentLng != 75.8577) {
              controller.animateCamera(CameraUpdate.newLatLng(LatLng(currentLat, currentLng)));
            }
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
          },
          circles: zones.map((zone) {
            return Circle(
              circleId: CircleId(zone.id),
              center: LatLng(zone.center.latitude, zone.center.longitude),
              radius: zone.radius * 1000,
              fillColor: _parseColor(zone.zoneColor).withValues(alpha: 0.3),
              strokeColor: _parseColor(zone.zoneColor),
              strokeWidth: 2,
            );
          }).toSet(),
        ) : const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text('Fetching your location...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSOSButton(BuildContext context, SOSProvider sosProvider) {
    final isSOSActive = sosProvider.isSOSActive;
    
    final safetyProvider = context.read<SafetyProvider>();
    
    return GestureDetector(
      onTap: () {
        if (isSOSActive) {
          safetyProvider.confirmSafe();
        } else {
          safetyProvider.triggerSOSFlow();
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSOSActive 
                ? [const Color(0xFF757575), const Color(0xFF9E9E9E)]
                : [const Color(0xFFCC0000), const Color(0xFFFF0000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isSOSActive 
                  ? Colors.grey.withValues(alpha: 0.3)
                  : const Color(0xFFFF0000).withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSOSActive ? Ionicons.close : Ionicons.navigate,
              size: 24,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text(
              isSOSActive ? 'CANCEL SOS' : 'TRIGGER SOS',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Color _parseColor(String colorString) {
    if (colorString.startsWith('#')) {
      return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
    }
    return const Color(0xFF43A047);
  }
}
