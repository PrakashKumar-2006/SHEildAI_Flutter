import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:ionicons/ionicons.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../../core/services/zone_service.dart';
import '../providers/routes_provider.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _destinationController = TextEditingController();
  bool _isDarkMode = false;

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final locationProvider = context.watch<LocationProvider>();
    final routesProvider = context.watch<RoutesProvider>();
    final zoneService = context.watch<ZoneService>();
    
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
              child: Row(
                children: [
                  Text(
                    'Route Planner',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Route Input Card
                    _buildRouteInputCard(context, routesProvider),
                    const SizedBox(height: 14),
                    // Map Card with Routes
                    _buildMapCard(context, locationProvider, routesProvider, zoneService),
                    const SizedBox(height: 14),
                    // Routes Section
                    _buildRoutesSection(context, routesProvider),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE3E6F0),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Ionicons.notifications_outline, size: 20),
              onPressed: () => Navigator.pushNamed(context, '/alerts'),
              color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInputCard(BuildContext context, RoutesProvider routesProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Current Location Row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Ionicons.location,
                  color: Color(0xFF1976D2),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Current Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Dotted Line
          Row(
            children: [
              const SizedBox(width: 16),
              Container(
                width: 2,
                height: 30,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Destination Input Row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFdc2626).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Ionicons.navigate,
                  color: Color(0xFFdc2626),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _destinationController,
                  decoration: InputDecoration(
                    hintText: 'Where are you heading?',
                    hintStyle: TextStyle(
                      color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF9E9E9E),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                    fontSize: 16,
                  ),
                  onSubmitted: (_) => _searchRoutes(),
                ),
              ),
              if (routesProvider.isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0D1B6E),
                  ),
                )
              else
                GestureDetector(
                  onTap: _searchRoutes,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1B6E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (routesProvider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                routesProvider.errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFdc2626),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapCard(BuildContext context, LocationProvider locationProvider, 
      RoutesProvider routesProvider, ZoneService zoneService) {
    final currentLocation = locationProvider.currentLocation;
    final currentLat = currentLocation?.latitude ?? 22.7196;
    final currentLng = currentLocation?.longitude ?? 75.8577;
    final routes = routesProvider.routes;
    final destination = routesProvider.destination;
    final zones = zoneService.zones;
    
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
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(currentLat, currentLng),
            zoom: 15.0,
          ),
          onMapCreated: (controller) => _mapController = controller,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          circles: zones.map((zone) {
            return Circle(
              circleId: CircleId(zone.id ?? zone.name),
              center: LatLng(zone.center.latitude, zone.center.longitude),
              radius: zone.radius * 1000,
              fillColor: _parseColor(zone.zoneColor).withValues(alpha: 0.3),
              strokeColor: _parseColor(zone.zoneColor),
              strokeWidth: 2,
            );
          }).toSet(),
          polylines: routes.asMap().entries.map((entry) {
            final index = entry.key;
            final route = entry.value;
            final isSelected = index == routesProvider.selectedRouteIndex;
            
            return Polyline(
              polylineId: PolylineId('route_$index'),
              points: route.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
              color: isSelected 
                  ? const Color(0xFF1976D2) 
                  : const Color(0xFF1976D2).withValues(alpha: 0.3),
              width: isSelected ? 6 : 3,
            );
          }).toSet(),
          markers: {
            if (destination != null)
              Marker(
                markerId: const MarkerId('destination'),
                position: LatLng(destination.latitude, destination.longitude),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(title: routesProvider.destinationName),
              ),
          },
        ),
      ),
    );
  }

  Widget _buildRoutesSection(BuildContext context, RoutesProvider routesProvider) {
    final routes = routesProvider.routes;
    
    if (routesProvider.isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
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
              'Analyzing safe routes...',
              style: TextStyle(
                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF9E9E9E),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    if (routes.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(
              Ionicons.search_outline,
              size: 40,
              color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
            ),
            const SizedBox(height: 12),
            Text(
              'Enter a destination to find safe routes',
              style: TextStyle(
                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF9E9E9E),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Section header
          Row(
            children: [
              Icon(
                Ionicons.shield_checkmark,
                size: 18,
                color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
              ),
              const SizedBox(width: 8),
              Text(
                'SAFEST ROUTES',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Route cards
          ...routes.asMap().entries.map((entry) {
            final index = entry.key;
            final route = entry.value;
            final isSelected = index == routesProvider.selectedRouteIndex;
            
            return _buildRouteCard(
              context,
              index,
              index == 0 ? 'Safest Route' : 'Alternative ${index + 1}',
              route.formattedDuration,
              route.formattedDistance,
              isSelected,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, int index, String name, String duration, 
      String distance, bool isSelected) {
    return GestureDetector(
      onTap: () {
        final routesProvider = context.read<RoutesProvider>();
        routesProvider.selectRoute(index);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF1976D2) 
                : (_isDarkMode ? const Color(0xFF334155) : const Color(0xFFE5E7EB)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF1976D2).withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          children: [
            // Route index
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected 
                    ? const Color(0xFF1976D2) 
                    : (_isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : (_isDarkMode ? Colors.white : const Color(0xFF0D1B6E)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Route info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Ionicons.time_outline,
                        size: 14,
                        color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        duration,
                        style: TextStyle(
                          fontSize: 13,
                          color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Ionicons.compass_outline,
                        size: 14,
                        color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: TextStyle(
                          fontSize: 13,
                          color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Safety badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: index == 0 
                    ? const Color(0xFF43A047).withValues(alpha: 0.1) 
                    : const Color(0xFFF39C12).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                index == 0 ? 'SAFEST' : 'MODERATE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: index == 0 ? const Color(0xFF43A047) : const Color(0xFFF39C12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _searchRoutes() async {
    final destination = _destinationController.text.trim();
    if (destination.isEmpty) return;
    
    final routesProvider = context.read<RoutesProvider>();
    final locationProvider = context.read<LocationProvider>();
    final currentLocation = locationProvider.currentLocation;
    final currentLat = currentLocation?.latitude ?? 22.7196;
    final currentLng = currentLocation?.longitude ?? 75.8577;
    final now = DateTime.now();
    
    final success = await routesProvider.searchAndCalculateRoutes(
      currentLat,
      currentLng,
      destination,
      hour: now.hour,
      month: now.month,
      isWeekend: now.weekday >= 5 ? 1 : 0,
    );
    
    if (success && routesProvider.routes.isNotEmpty && _mapController != null) {
      // Fit map to show all routes
      double minLat = double.infinity;
      double minLng = double.infinity;
      double maxLat = -double.infinity;
      double maxLng = -double.infinity;

      for (var route in routesProvider.routes) {
        for (var point in route.points) {
          if (point.latitude < minLat) minLat = point.latitude;
          if (point.latitude > maxLat) maxLat = point.latitude;
          if (point.longitude < minLng) minLng = point.longitude;
          if (point.longitude > maxLng) maxLng = point.longitude;
        }
      }

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  Color _parseColor(String colorString) {
    if (colorString.startsWith('#')) {
      return Color(int.parse(colorString.substring(1), radix: 16) + 0xFF000000);
    }
    return const Color(0xFF43A047);
  }
}
