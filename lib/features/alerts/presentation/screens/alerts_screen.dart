import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

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
                        // Alert Feed
                        _buildAlertFeed(context),
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

  Widget _buildAlertFeed(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Safety Alert Feed',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
            ),
          ),
          const SizedBox(height: 12),
          // Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 2,
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
                    color: _isDarkMode ? const Color(0xFF064e3b) : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Ionicons.shield_checkmark,
                    size: 20,
                    color: Color(0xFF43A047),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Vigilant',
                        style: const TextStyle(
                          color: Color(0xFF43A047),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No alerts in your area',
                        style: TextStyle(
                          color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                          fontSize: 12,
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

  void _submitReport() {
    if (_reportDesc.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide a brief description of the incident.')),
        );
      }
      return;
    }
    setState(() => _submitting = true);
    // Simulate API call
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _submitting = false;
          _showReportModal = false;
          _reportDesc = '';
          _reportSeverity = 5;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your report has been shared anonymously with the community.')),
        );
      }
    });
  }
}
