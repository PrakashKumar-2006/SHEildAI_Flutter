import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:ionicons/ionicons.dart';
import '../providers/home_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _isDarkMode = theme.brightness == Brightness.dark;

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
                        _buildSafetyCard(context, homeProvider),
                        const SizedBox(height: 20),
                        // Safety Intelligence Section
                        _buildIntelligenceSection(context, homeProvider),
                        const SizedBox(height: 14),
                        // Search Bar
                        _buildSearchCard(context),
                        const SizedBox(height: 14),
                        // Voice Detection Toggle
                        _buildVoiceCard(context, homeProvider),
                        const SizedBox(height: 14),
                        // Map Card
                        _buildMapCard(context, homeProvider),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, HomeProvider homeProvider) {
    final theme = Theme.of(context);
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

  Widget _buildSafetyCard(BuildContext context, HomeProvider homeProvider) {
    final riskColor = _getRiskColor(homeProvider.currentRiskLevel);
    final riskBg = _getRiskBg(homeProvider.currentRiskLevel);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          // Safety Circle
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: riskBg,
            ),
            child: Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isDarkMode 
                      ? 'rgba(255, 255, 255, 0.05)'.toColor() 
                      : 'rgba(255, 255, 255, 0.4)'.toColor(),
                ),
                child: Center(
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          homeProvider.currentRiskLevel == 'SAFE' ? 'SAFE ZONE' : 'DANGER LEVEL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: riskColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${homeProvider.safetyScore}',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                                height: 1.0,
                              ),
                            ),
                            Text(
                              '%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
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
              color: riskColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  homeProvider.currentRiskLevel == 'SAFE' 
                      ? Ionicons.shield_checkmark 
                      : Ionicons.warning,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  homeProvider.currentRiskLevel == 'SAFE' 
                      ? 'I AM SAFE' 
                      : '${homeProvider.currentRiskLevel} RISK',
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
            homeProvider.currentLocation,
            style: TextStyle(
              color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntelligenceSection(BuildContext context, HomeProvider homeProvider) {
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(3, (index) {
                    final hour = DateTime.now().hour + index;
                    final risk = homeProvider.safetyScore - (index * 10);
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
                  }),
                ),
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
                          'Safest travel window: 10:00 AM',
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

  Widget _buildVoiceCard(BuildContext context, HomeProvider homeProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: homeProvider.isVoiceModeEnabled 
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
              color: homeProvider.isVoiceModeEnabled
                  ? (_isDarkMode ? 'rgba(239,68,68,0.18)'.toColor() : 'rgba(220,38,38,0.10)'.toColor())
                  : (_isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              homeProvider.isVoiceModeEnabled ? Ionicons.mic : Ionicons.mic_off_outline,
              size: 20,
              color: homeProvider.isVoiceModeEnabled 
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
                  homeProvider.isVoiceModeEnabled 
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
            value: homeProvider.isVoiceModeEnabled,
            onChanged: (value) => homeProvider.toggleVoiceMode(),
            activeTrackColor: const Color(0xFFdc2626),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(BuildContext context, HomeProvider homeProvider) {
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(homeProvider.currentLatitude, homeProvider.currentLongitude),
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sheildai.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(homeProvider.currentLatitude, homeProvider.currentLongitude),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withValues(alpha: 0.2),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'CRITICAL':
        return const Color(0xFF8B0000);
      case 'HIGH':
        return const Color(0xFFFF4D4D);
      case 'MEDIUM':
        return const Color(0xFFFFD700);
      case 'SAFE':
        return const Color(0xFF43A047);
      default:
        return const Color(0xFF43A047);
    }
  }

  Color _getRiskBg(String riskLevel) {
    switch (riskLevel) {
      case 'CRITICAL':
        return 'rgba(139, 0, 0, 0.1)'.toColor();
      case 'HIGH':
        return 'rgba(255, 77, 77, 0.1)'.toColor();
      case 'MEDIUM':
        return 'rgba(255, 215, 0, 0.1)'.toColor();
      case 'SAFE':
        return 'rgba(76, 175, 80, 0.1)'.toColor();
      default:
        return 'rgba(76, 175, 80, 0.1)'.toColor();
    }
  }
}

extension ColorExtension on String {
  Color toColor() {
    final hexColor = replaceAll('#', '');
    if (hexColor.length == 6) {
      return Color(int.parse('FF$hexColor', radix: 16));
    } else if (hexColor.length == 8) {
      return Color(int.parse(hexColor, radix: 16));
    }
    return Colors.black;
  }
}
