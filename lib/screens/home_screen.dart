import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';
import '../widgets/notification_bell_popup.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  String _locationName = 'Scanning safe corridors...';

  bool _isNightTime() {
    final hour = DateTime.now().hour;
    return hour >= 20 || hour < 6;
  }

  Color _getRiskColor(String label) {
    switch (label) {
      case 'CRITICAL': return const Color(0xFF8B0000);
      case 'HIGH': return const Color(0xFFFF4D4D);
      case 'MEDIUM': return const Color(0xFFFFD700);
      case 'SAFE': return const Color(0xFF43A047);
      default: return const Color(0xFF43A047);
    }
  }

  Color _getRiskBg(String label, bool isDark) {
    switch (label) {
      case 'CRITICAL': return const Color(0xFF8B0000).withOpacity(0.1);
      case 'HIGH': return const Color(0xFFFF4D4D).withOpacity(0.1);
      case 'MEDIUM': return const Color(0xFFFFD700).withOpacity(0.1);
      default: return const Color(0xFF4CAF50).withOpacity(0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();
    final safety = context.watch<SafetyProvider>();
    final isDark = theme.isDarkMode;

    final riskLabel = safety.riskLabel;
    final riskScore = safety.riskScore;
    final riskColor = _getRiskColor(riskLabel);
    final riskBg = _getRiskBg(riskLabel, isDark);

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(theme, lang, context),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Safety Score Circle
                    _buildSafetyScoreCard(riskLabel, riskScore, riskColor, riskBg, isDark, theme, lang, safety),
                    const SizedBox(height: 20),
                    // Safety Insights
                    _buildSafetyInsightsCard(theme, isDark),
                    const SizedBox(height: 20),
                    // Search Bar → Routes
                    _buildSearchCard(theme, lang, context),
                    const SizedBox(height: 14),
                    // Voice Detection Toggle
                    _buildVoiceCard(theme, lang, safety, isDark),
                    const SizedBox(height: 14),
                    // Map
                    _buildMapCard(theme, safety),
                    const SizedBox(height: 40),
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
      Color riskBg, bool isDark, ThemeProvider theme, LanguageProvider lang, SafetyProvider safety) {
    return Column(
      children: [
        // Triple circle
        Container(
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
        const SizedBox(height: 16),
        // Status badge
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
        Text(
          safety.riskZone,
          style: TextStyle(color: theme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
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

  Widget _buildSafetyInsightsCard(ThemeProvider theme, bool isDark) {
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
                color: const Color(0xFF0D1B6E),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1e3a8a) : const Color(0xFFF0F2FF),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.workspace_premium_rounded, size: 28, color: isDark ? const Color(0xFF60a5fa) : const Color(0xFF0D1B6E)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: isDark ? const Color(0xFF60a5fa) : theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Unlock 3-hour risk forecasting and safest travel time analysis.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF93c5fd) : theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: isDark ? const Color(0xFF60a5fa) : theme.accent),
              ],
            ),
          ),
        ),
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
          onTap: () {/* Navigate to Routes */},
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
            activeColor: const Color(0xFFef4444),
            activeTrackColor: isDark ? const Color(0xFFef4444).withOpacity(0.5) : const Color(0xFFef4444).withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(ThemeProvider theme, SafetyProvider safety) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: LatLng(safety.latitude, safety.longitude),
          initialZoom: 14,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.shieldai.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(safety.latitude, safety.longitude),
                width: 24,
                height: 24,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1976D2).withOpacity(0.2),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(
                    child: CircleAvatar(radius: 5, backgroundColor: Color(0xFF1976D2)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
