import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import '../../../community/presentation/providers/community_provider.dart';
import '../../../location/presentation/providers/location_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../core/services/storage_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _isDarkMode = false;
  bool _showReportModal = false;
  String _reportType = 'Suspicious person following';
  String _reportDesc = '';
  int _reportSeverity = 5;
  bool _submitting = false;
  GoogleMapController? _mapController;

  final List<String> _incidentTypes = [
    "Suspicious person following",
    "Harassment",
    "Poorly lit area",
    "Isolated road",
    "Drug activity",
    "Vehicle following",
    "Unsafe street vendor area",
    "Other",
  ];

  @override
  Widget build(BuildContext context) {
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                _buildHeader(context),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Report Observation Card
                        _buildObservationCard(context),
                        const SizedBox(height: 16),
                        // Safety Alert Feed
                        Consumer<CommunityProvider>(
                          builder: (context, communityProvider, child) {
                            return _buildAlertFeed(context, communityProvider);
                          },
                        ),
                        const SizedBox(height: 16),
                        // Map showing alerts
                        Consumer2<LocationProvider, CommunityProvider>(
                          builder: (context, locationProvider, communityProvider, child) {
                            return _buildAlertsMap(context, locationProvider, communityProvider);
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Floating SOS Button
            Positioned(
              bottom: 20,
              right: 20,
              child: _buildFloatingSOS(context),
            ),
            // Report Modal
            if (_showReportModal) _buildReportModal(context),
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

  Widget _buildObservationCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Ionicons.eye_outline,
              size: 24,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 12),
          // Title
          Text(
            'Report Observation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
            ),
          ),
          const SizedBox(height: 8),
          // Subtitle
          Text(
            'See something suspicious? Help protect the community by sharing anonymously.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // Report Button
          GestureDetector(
            onTap: () => setState(() => _showReportModal = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF1976D2),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Text(
                'Report Now',
                style: TextStyle(
                  color: Color(0xFF1976D2),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertFeed(BuildContext context, CommunityProvider communityProvider) {
    final reports = communityProvider.reports;
    
    if (communityProvider.isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Safety Alert Feed',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
            ),
          ),
          const SizedBox(height: 12),
          if (reports.isEmpty)
            Text(
              'No recent alerts in your area',
              style: TextStyle(
                fontSize: 14,
                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
              ),
            )
          else
            ...reports.take(5).map((report) => _buildAlertItem(context, report)),
        ],
      ),
    );
  }

  Widget _buildAlertsMap(BuildContext context, LocationProvider locationProvider, CommunityProvider communityProvider) {
    final reports = communityProvider.reports;
    final currentLocation = locationProvider.currentLocation;
    final currentLat = currentLocation?.latitude ?? 22.7196;
    final currentLng = currentLocation?.longitude ?? 75.8577;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 200,
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(currentLat, currentLng),
            zoom: 13.0,
          ),
          onMapCreated: (controller) => _mapController = controller,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: reports.map((report) {
            return Marker(
              markerId: MarkerId(report.id.toString()),
              position: LatLng(report.latitude, report.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: report.incidentType,
                snippet: report.description,
              ),
            );
          }).toSet(),
        ),
      ),
    );
  }

  Widget _buildAlertItem(BuildContext context, dynamic report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE0E0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Ionicons.warning,
              size: 20,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.incidentType ?? 'Safety Alert',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  report.description ?? 'No description',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${report.severity ?? 5}/10',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingSOS(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFCC0000), Color(0xFFFF0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF0000).withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Ionicons.navigate,
        size: 24,
        color: Colors.white,
      ),
    );
  }

  Widget _buildReportModal(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showReportModal = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Community Alert',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _showReportModal = false),
                          child: Icon(
                            Ionicons.close,
                            size: 24,
                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Incident Type
                    Text(
                      'Incident Type',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _incidentTypes.map((type) {
                        final isSelected = _reportType == type;
                        return GestureDetector(
                          onTap: () => setState(() => _reportType = type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? const Color(0xFF0D1B6E) 
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected 
                                    ? const Color(0xFF0D1B6E) 
                                    : (_isDarkMode ? const Color(0xFF334155) : const Color(0xFFE0E0E0)),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected 
                                    ? Colors.white 
                                    : (_isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575)),
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Description
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        maxLines: 4,
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
                        ),
                        decoration: InputDecoration(
                          hintText: 'What did you see? (e.g. Man in black hoodie following since 10 mins)',
                          hintStyle: TextStyle(
                            color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                          ),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) => setState(() => _reportDesc = value),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Severity
                    Text(
                      'Severity ($_reportSeverity/10)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(10, (index) {
                        final severity = index + 1;
                        final isSelected = _reportSeverity >= severity;
                        return GestureDetector(
                          onTap: () => setState(() => _reportSeverity = severity),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? (severity > 7 
                                      ? const Color(0xFFC62828) 
                                      : severity > 4 
                                          ? const Color(0xFFE65100) 
                                          : const Color(0xFF43A047))
                                  : (_isDarkMode ? const Color(0xFF334155) : const Color(0xFFE0E0E0)),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    // Privacy Notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isDarkMode ? const Color(0xFF1e293b) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Ionicons.lock_closed,
                            size: 14,
                            color: Color(0xFF757575),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your report is 100% anonymous. Profiles are never shared.',
                              style: TextStyle(
                                fontSize: 11,
                                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Submit Button
                    GestureDetector(
                      onTap: _submitting ? null : _submitReport,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1B6E),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _submitting ? 'Submitting...' : 'Post Community Alert',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitReport() async {
    if (_reportDesc.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide a brief description of the incident.')),
        );
      }
      return;
    }
    
    final communityProvider = Provider.of<CommunityProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final currentLocation = locationProvider.currentLocation;
    
    setState(() => _submitting = true);
    
    await communityProvider.submitReport(
      phone: StorageService().getUserPhone(),
      latitude: currentLocation?.latitude ?? 22.7196,
      longitude: currentLocation?.longitude ?? 75.8577,
      incidentType: _reportType,
      description: _reportDesc,
      severity: _reportSeverity,
      anonymous: true,
    );
    
    if (mounted) {
      setState(() {
        _submitting = false;
        _showReportModal = false;
        _reportDesc = '';
        _reportSeverity = 5;
      });
      
      if (communityProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${communityProvider.errorMessage}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your report has been shared anonymously with the community.')),
        );
      }
    }
  }
}
