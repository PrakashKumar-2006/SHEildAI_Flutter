import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import '../providers/providers.dart';
import '../features/community/presentation/providers/community_provider.dart';
import '../core/app_theme.dart';
import '../widgets/notification_bell_popup.dart';
import 'profile_screen.dart';
import 'main_screen.dart';
import 'alerts_screen.dart';
import '../shared/widgets/crowd_risk_indicator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  final Set<Circle> _circles = {};

  bool _isNightTime() {
    final hour = DateTime.now().hour;
    return hour >= 21 || hour < 6;
  }

  Color _parseHexColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  void _updateCircles(SafetyProvider safety) {
    _circles.clear();
    for (final zone in safety.zones) {
      final color = _parseHexColor(zone.zoneColor);
      _circles.add(
        Circle(
          circleId: CircleId(zone.id),
          center: LatLng(zone.center.latitude, zone.center.longitude),
          radius: zone.radius * 1000,
          fillColor: color.withOpacity(0.3),
          strokeColor: color,
          strokeWidth: 2,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();
    final safety = context.watch<SafetyProvider>();
    final community = context.watch<CommunityProvider>();
    final isDark = theme.isDarkMode;

    final riskLabel = safety.riskLabel;
    final riskScore = safety.riskScore;
    final riskColor = _parseHexColor(safety.riskColor);
    final alerts = safety.riskAlerts;

    _updateCircles(safety);
    
    // Add markers - ONLY user position as requested. Community reports are hidden.
    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('current_pos'),
        position: LatLng(safety.latitude ?? 22.7196, safety.longitude ?? 75.8577),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };
    if (_mapController != null && safety.latitude != null && safety.longitude != null) {
      final targetLat = safety.latitude!;
      final targetLon = safety.longitude!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(targetLat, targetLon)),
        );
      });
    }

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(theme, lang, context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _buildSafetyScoreCard(riskLabel, riskScore, riskColor, isDark, theme, lang, safety),
                        const SizedBox(height: 16),
                        _buildSafetyInsightsCard(theme, isDark, safety),
                        const SizedBox(height: 20),
                        if (alerts.isNotEmpty) _buildRiskAlertsList(theme, alerts, isDark),
                        const SizedBox(height: 14),
                        _buildSearchCard(theme, lang, context),
                        const SizedBox(height: 14),
                        _buildVoiceCard(theme, lang, safety, isDark),
                        const SizedBox(height: 14),
                        _buildMapCard(theme, safety, markers),
                        const SizedBox(height: 16),
                        _buildExploreFeedCard(theme, context),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (safety.isSirenPlaying)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC62828),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ZONE ALERT ACTIVE',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
                            ),
                            Text(
                              'Siren playing... Be aware!',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: safety.stopSiren,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider theme, LanguageProvider lang, BuildContext context) {
    return Container(
      color: theme.background,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_rounded, color: theme.textPrimary, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            lang.t('shield_ai'),
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          NotificationBellPopup(iconColor: theme.textPrimary),
        ],
      ),
    );
  }

  Widget _buildSafetyScoreCard(String riskLabel, int riskScore, Color riskColor,
      bool isDark, ThemeProvider theme, LanguageProvider lang, SafetyProvider safety) {
    return Column(
      children: [
        // Triple circle
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showRiskBreakdown(context, safety, theme, riskColor, isDark),
          child: Container(
            width: 170,
            height: 170,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: riskColor.withOpacity(0.1),
          ),
          child: Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.4),
              ),
              child: Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.surface,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        riskLabel == 'SAFE'
                            ? lang.t('safe_zone_label')
                            : lang.t('danger_level'),
                        style: TextStyle(
                          color: riskColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$riskScore',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '%',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
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
      ),
      const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: riskColor,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                riskLabel == 'SAFE' ? Icons.shield_rounded : Icons.warning_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                riskLabel == 'SAFE'
                    ? lang.t('i_am_safe_title')
                    : '$riskLabel ${lang.t('risk_label').toUpperCase()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            safety.readableAddress,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        if (_isNightTime()) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.nightlight_round, size: 14, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF5C6BC0)),
                const SizedBox(width: 6),
                Text(
                  lang.t('night_multiplier_active').replaceAll('{{value}}', '2'),
                  style: TextStyle(
                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF5C6BC0),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSafetyInsightsCard(ThemeProvider theme, bool isDark, SafetyProvider safety) {
    final forecast = safety.forecast;
    final travelTime = safety.bestTravelTime;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 18, color: theme.textPrimary),
            const SizedBox(width: 8),
            Text(
              'SAFETY INSIGHTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0D1B6E),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        if (safety.forecast == null)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D1B6E)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Loading Safety Intelligence...',
                    style: TextStyle(fontSize: 11, color: theme.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else if (forecast != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('3-Hour Forecast', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: (forecast['forecast'] as List? ?? []).take(3).map((f) {
                    final h = f['hour'] as int;
                    final s = (f['risk_score'] as num).toInt();
                    return Column(
                      children: [
                        Text('$h:00', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('$s%', style: TextStyle(fontWeight: FontWeight.w900, color: _parseHexColor(f['risk_color'] ?? '#4CAF50'))),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (travelTime != null && (travelTime['safest_hours'] as List?)?.isNotEmpty == true) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064e3b) : const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF43A047).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Color(0xFF43A047), size: 20),
                    const SizedBox(width: 8),
                    const Text('Best Travel Windows', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1B5E20))),
                  ],
                ),
                const SizedBox(height: 12),
                ...(travelTime['safest_hours'] as List).take(3).map((hourData) {
                  final h = hourData['hour'] as int;
                  final s = ((hourData['risk_score'] as num) * 100).toInt();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$h:00', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1B5E20))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF43A047), borderRadius: BorderRadius.circular(8)),
                          child: Text('${100 - s}% Safe', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildRiskAlertsList(ThemeProvider theme, List<String> alerts, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        ...alerts.map((alert) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D1B1B) : const Color(0xFFFFF1F1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFCDD2).withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD32F2F)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alert,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFD32F2F), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildSearchCard(ThemeProvider theme, LanguageProvider lang, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pushNamed('/routes'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
            child: Row(
              children: [
                Icon(Icons.navigation_outlined, color: theme.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.t('where_heading'),
                    style: TextStyle(color: theme.textPrimary, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    lang.t('safe_route'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceCard(ThemeProvider theme, LanguageProvider lang, SafetyProvider safety, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: safety.isSafetyModeActive
              ? (isDark ? const Color(0xFFef4444) : const Color(0xFFdc2626))
              : theme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: safety.isSafetyModeActive
                  ? (isDark ? const Color(0x2Fef4444) : const Color(0x1Adc2626))
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              safety.isSafetyModeActive ? Icons.mic_rounded : Icons.mic_off_outlined,
              color: safety.isSafetyModeActive ? const Color(0xFFef4444) : theme.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Detection',
                  style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  safety.isSafetyModeActive ? '🔴 Listening for "help"…' : 'Say "help" to trigger SOS',
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: safety.isSafetyModeActive,
            onChanged: (v) => safety.setVoiceListening(v),
            activeThumbColor: const Color(0xFFef4444),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(ThemeProvider theme, SafetyProvider safety, Set<Marker> markers) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(safety.latitude ?? 22.7196, safety.longitude ?? 75.8577),
          zoom: 14,
        ),
        onMapCreated: (controller) => _mapController = controller,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        tiltGesturesEnabled: true,
        rotateGesturesEnabled: true,
        gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
        },
        circles: _circles,
        markers: markers,
      ),
    );
  }

  void _showRiskBreakdown(BuildContext context, SafetyProvider safety, ThemeProvider theme, Color riskColor, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.analytics_rounded, color: riskColor, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    "Risk Calculation Factors",
                    style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Here is how your current safety score is calculated:",
                style: TextStyle(color: theme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              const CrowdRiskIndicator(),
              const SizedBox(height: 24),
              
              // Factor 1: ML Score
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.memory_rounded, color: Colors.blue, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("AI Predicted Crime Risk", style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text("Based on historical data, time, and weather.", style: TextStyle(color: theme.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ),
                    Text("${safety.mlRiskScore}%", style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Factor 2: Zone Score
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.map_rounded, color: Colors.orange, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Zone Danger Level", style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text("Current Zone: ${safety.currentZoneName}", style: TextStyle(color: theme.textSecondary, fontSize: 10)),
                        ],
                      ),
                    ),
                    Text("${safety.zoneRiskScore}%", style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              
              if (safety.riskAlerts.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  "ACTIVE ALERTS",
                  style: TextStyle(
                    color: theme.textSecondary.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                ...safety.riskAlerts.map((alert) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFC62828)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(alert, style: const TextStyle(color: Color(0xFFC62828), fontSize: 12, fontWeight: FontWeight.w600))),
                    ],
                  ),
                )),
              ],
              
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF5C6BC0)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "The main risk score is the maximum of the AI Prediction and the Zone Danger Level.",
                        style: TextStyle(color: isDark ? const Color(0xFF818CF8) : const Color(0xFF5C6BC0), fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExploreFeedCard(ThemeProvider theme, BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.accent.withOpacity(0.8), theme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.accent.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.explore_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STAY UPDATED. STAY SAFE.',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Check safety alerts, tips, and campaigns.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AlertsScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Explore Feed', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
