import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ionicons/ionicons.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  final MapController _mapController = MapController();
  bool _isDarkMode = false;
  String _destination = '';
  String _currentLoc = 'Current Location';
  bool _loading = false;
  bool _isNavigating = false;
  int _selectedRoute = 0;

  @override
  Widget build(BuildContext context) {
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            // Page Title
            Container(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
              child: Text(
                'Route Planner',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                ),
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Route Input Card
                    _buildRouteInputCard(context),
                    const SizedBox(height: 14),
                    // Map
                    _buildMapCard(context),
                    const SizedBox(height: 14),
                    // Routes Section
                    _buildRoutesSection(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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


  Widget _buildRouteInputCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Current Location
          Row(
            children: [
              const Icon(Ionicons.locate, size: 18, color: Color(0xFF0D1B6E)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _currentLoc,
                  style: TextStyle(
                    fontSize: 14,
                    color: _isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.only(left: 30),
            color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFF0F0F0),
          ),
          const SizedBox(height: 8),
          // Destination
          Row(
            children: [
              const Icon(Ionicons.location, size: 18, color: Color(0xFF0D1B6E)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  style: TextStyle(
                    fontSize: 14,
                    color: _isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Where to?',
                    hintStyle: TextStyle(
                      color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => setState(() => _destination = value),
                ),
              ),
              GestureDetector(
                onTap: () => _searchRoutes(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B6E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Ionicons.search,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          // Blue accent
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 4,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF1976D2),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 450,
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
            initialCenter: const LatLng(22.7196, 75.8577),
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
                  point: const LatLng(22.7196, 75.8577),
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

  Widget _buildRoutesSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (_loading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Icon(
                    Ionicons.sync_outline,
                    size: 40,
                    color: Color(0xFF0D1B6E),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Analyzing...',
                    style: TextStyle(
                      color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF9E9E9E),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else if (_destination.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Icon(
                    Ionicons.search_outline,
                    size: 40,
                    color: Color(0xFF9E9E9E),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter destination',
                    style: TextStyle(
                      color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF9E9E9E),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            _buildRouteCard(context, 0, 'Safest Path', '15 mins', '3.2 km', 25),
        ],
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, int index, String name, String duration, String distance, int riskLevel) {
    final isSelected = _selectedRoute == index;
    final riskColor = riskLevel <= 30 
        ? const Color(0xFF43A047) 
        : riskLevel <= 55 
            ? const Color(0xFFFFD700) 
            : const Color(0xFFFF4D4D);
    
    return GestureDetector(
      onTap: () => setState(() => _selectedRoute = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? riskColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon Circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isDarkMode 
                    ? (riskLevel <= 30 ? const Color(0xFF064e3b) : const Color(0xFF78350f))
                    : (riskLevel <= 30 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                riskLevel <= 30 ? Ionicons.shield_checkmark : Ionicons.warning,
                size: 20,
                color: riskColor,
              ),
            ),
            const SizedBox(width: 12),
            // Score
            Column(
              children: [
                Text(
                  '$riskLevel%',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: riskColor,
                  ),
                ),
                Text(
                  'Danger Level',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                    ),
                  ),
                  Text(
                    '$duration • $distance',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF9E9E9E),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isDarkMode 
                          ? (riskLevel <= 25 ? const Color(0xFF064e3b) : const Color(0xFF7f1d1d))
                          : (riskLevel <= 25 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      riskLevel <= 25 ? 'Optimized Safety' : 'High Risk Zone',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: riskLevel <= 25 
                            ? const Color(0xFF2E7D32) 
                            : const Color(0xFFea580c),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Navigate Button
            if (isSelected && !_isNavigating)
              GestureDetector(
                onTap: () => setState(() => _isNavigating = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1B6E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Ionicons.play_circle,
                        size: 24,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Navigate',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
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

  void _searchRoutes() {
    if (_destination.isEmpty) return;
    setState(() => _loading = true);
    // Simulate API call
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _loading = false);
    });
  }
}
