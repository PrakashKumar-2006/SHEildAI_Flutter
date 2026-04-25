import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:ionicons/ionicons.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../../core/services/zone_service.dart';
import '../providers/routes_provider.dart';
import '../../../../core/services/osrm_service.dart';
import '../../../../core/models/zone_model.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _destinationController = TextEditingController();
  bool _isDarkMode = false;
  BitmapDescriptor? _dangerIcon;

  @override
  void initState() {
    super.initState();
    _createDangerIcon();
  }

  Future<void> _createDangerIcon() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = Colors.red;
    
    final Path path = Path();
    path.moveTo(24, 0);
    path.lineTo(48, 42);
    path.lineTo(0, 42);
    path.close();
    canvas.drawPath(path, paint);

    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = const TextSpan(
      text: '!',
      style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(18, 8));

    final img = await pictureRecorder.endRecording().toImage(48, 48);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (mounted) {
      setState(() {
        _dangerIcon = BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
      });
    }
  }

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
            color: Colors.black.withOpacity(0.06),
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
                  color: const Color(0xFF1976D2).withOpacity(0.1),
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
          // Destination Input Row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFdc2626).withOpacity(0.1),
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
      height: 400,
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.hardEdge,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(currentLat, currentLng),
          zoom: 15.0,
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
        circles: (destination != null) ? zones.map((zone) {
          final color = zone.riskScore > 75 ? Colors.red : 
                       zone.riskScore > 50 ? Colors.orange : 
                       zone.riskScore > 25 ? Colors.yellow : Colors.green;
          return Circle(
            circleId: CircleId(zone.id),
            center: LatLng(zone.center.latitude, zone.center.longitude),
            radius: 1000, // Enforce 1km radius
            fillColor: color.withOpacity(0.2),
            strokeColor: color,
            strokeWidth: 2,
          );
        }).toSet() : {},
        polylines: routes.asMap().entries.map((entry) {
          final index = entry.key;
          final route = entry.value;
          final isSelected = index == routesProvider.selectedRouteIndex;
          
          Color routeColor;
          if (isSelected) {
            routeColor = route.riskScore > 75 ? const Color(0xFFD32F2F) : 
                        route.riskScore > 50 ? const Color(0xFFF57C00) : 
                        route.riskScore > 25 ? const Color(0xFFFBC02D) : const Color(0xFF43A047);
          } else {
            routeColor = Colors.grey.withOpacity(0.4);
          }

          return Polyline(
            polylineId: PolylineId('route_$index'),
            points: route.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
            color: routeColor,
            width: isSelected ? 6 : 4,
            zIndex: isSelected ? 10 : 1,
          );
        }).toSet(),
        markers: {
          if (destination != null)
            Marker(
              markerId: const MarkerId('destination'),
              position: LatLng(destination.latitude, destination.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: const InfoWindow(title: 'Destination'),
            ),
          Marker(
            markerId: const MarkerId('origin'),
            position: LatLng(currentLat, currentLng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(title: 'Your Location'),
          ),
          // Add risk markers for the selected route
          ..._buildRiskMarkers(routesProvider.selectedRoute, zones),
        },
      ),
    );
  }

  Widget _buildRoutesSection(BuildContext context, RoutesProvider routesProvider) {
    final routes = routesProvider.routes;
    if (routes.isEmpty) return const SizedBox();
    
    return Column(
      children: routes.asMap().entries.map((entry) {
        final index = entry.key;
        final route = entry.value;
        final isSelected = index == routesProvider.selectedRouteIndex;
        
        return GestureDetector(
          onTap: () => routesProvider.selectRoute(index),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0D1B6E).withOpacity(0.05) : _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? const Color(0xFF0D1B6E) : Colors.transparent),
            ),
            child: Row(
              children: [
                const Icon(Ionicons.trail_sign_outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(index == 0 ? 'Safest Route' : 'Alternative Route ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${route.formattedDistance} • ${route.formattedDuration} • Risk: ${route.riskScore.toStringAsFixed(1)}%', 
                        style: TextStyle(
                          fontSize: 12, 
                          color: route.riskScore > 75 ? Colors.red : (route.riskScore > 50 ? Colors.orange : Colors.grey)
                        )
                      ),
                    ],
                  ),
                ),
                if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF0D1B6E)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Marker> _buildRiskMarkers(OSRMRoute? route, List<ZoneModel> zones) {
    if (route == null) return [];
    
    final markers = <Marker>[];
    final points = route.points;
    
    // Sample points along the route (every ~10th point)
    for (int i = 0; i < points.length; i += 10) {
      final point = points[i];
      for (final zone in zones) {
        if (zone.riskScore > 50) { // Only high/critical zones
          final distance = OSRMService.calculateDistance(
            point.latitude, point.longitude, 
            zone.center.latitude, zone.center.longitude
          );
          
          if (distance < (zone.radius * 1000)) { // Within zone radius (converted to meters)
            markers.add(
              Marker(
                markerId: MarkerId('risk_${zone.id}_$i'),
                position: LatLng(point.latitude, point.longitude),
                icon: _dangerIcon ?? BitmapDescriptor.defaultMarkerWithHue(
                  zone.riskScore > 75 ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange
                ),
                anchor: const Offset(0.5, 0.5),
                infoWindow: InfoWindow(title: 'Risk Area: ${zone.name}', snippet: 'Score: ${zone.riskScore}%'),
              ),
            );
            break; // Don't add multiple markers for the same point
          }
        }
      }
    }
    return markers;
  }

  void _searchRoutes() async {
    final dest = _destinationController.text.trim();
    if (dest.isEmpty) return;
    
    final routesProvider = context.read<RoutesProvider>();
    final loc = context.read<LocationProvider>().currentLocation;
    if (loc == null) return;
    
    await routesProvider.searchAndCalculateRoutes(
      loc.latitude, loc.longitude, dest,
      hour: DateTime.now().hour,
      month: DateTime.now().month,
    );
    
    if (routesProvider.destination != null && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(routesProvider.destination!.latitude, routesProvider.destination!.longitude)));
    }
  }
}
