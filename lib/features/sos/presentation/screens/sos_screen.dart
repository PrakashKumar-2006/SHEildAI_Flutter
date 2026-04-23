import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ionicons/ionicons.dart';
import '../providers/sos_provider.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Consumer<SOSProvider>(
          builder: (context, sosProvider, child) {
            return Column(
              children: [
                // Header
                _buildHeader(context, sosProvider),
                // Main Content
                Expanded(
                  child: Stack(
                    children: [
                      // Background pulse effect
                      if (sosProvider.isSOSActive)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(0xFFDC2626).withValues(alpha: 0.1 * _pulseAnimation.value),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 1.0],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      // Main content
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Status indicator
                            if (sosProvider.isSOSActive) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: const Color(0xFFDC2626),
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Ionicons.radio_button_on,
                                      color: Color(0xFFDC2626),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'SOS ACTIVE',
                                      style: TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],
                            // SOS Button
                            GestureDetector(
                              onTapDown: (_) => _scaleController.forward(),
                              onTapUp: (_) {
                                _scaleController.reverse();
                                if (sosProvider.isSOSActive) {
                                  sosProvider.cancelSOS();
                                } else {
                                  sosProvider.triggerSOS();
                                }
                              },
                              onTapCancel: () => _scaleController.reverse(),
                              child: AnimatedBuilder(
                                animation: _scaleAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _scaleAnimation.value,
                                    child: Container(
                                      width: 200,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: sosProvider.isSOSActive
                                              ? [const Color(0xFF1B5E20), const Color(0xFF43A047)]
                                              : [const Color(0xFFCC0000), const Color(0xFFFF0000)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: sosProvider.isSOSActive
                                                ? const Color(0xFF43A047).withValues(alpha: 0.4)
                                                : const Color(0xFFFF0000).withValues(alpha: 0.4),
                                            blurRadius: 30,
                                            spreadRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            sosProvider.isSOSActive
                                                ? Ionicons.shield_checkmark
                                                : Ionicons.navigate,
                                            size: 60,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            sosProvider.isSOSActive ? 'I\'M SAFE' : 'SOS',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Session info
                            if (sosProvider.isSOSActive) ...[
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 40),
                                padding: const EdgeInsets.all(20),
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
                                    _buildSessionRow(
                                      'Duration',
                                      sosProvider.sessionDuration,
                                      Ionicons.time_outline,
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 1,
                                      color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFF0F0F0),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildSessionRow(
                                      'Location',
                                      sosProvider.currentLocation,
                                      Ionicons.location_outline,
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 1,
                                      color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFF0F0F0),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildSessionRow(
                                      'Status',
                                      'Alerting Contacts',
                                      Ionicons.notifications_outline,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            // Instructions
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                sosProvider.isSOSActive
                                    ? 'Tap to confirm you are safe'
                                    : 'Press and hold to trigger emergency SOS',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Error message
                            if (sosProvider.errorMessage != null) ...[
                              const SizedBox(height: 20),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 40),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFDC2626),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Ionicons.warning_outline,
                                      color: Color(0xFFDC2626),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        sosProvider.errorMessage!,
                                        style: const TextStyle(
                                          color: Color(0xFFDC2626),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Ionicons.close, size: 20),
                                      onPressed: sosProvider.clearError,
                                      color: const Color(0xFFDC2626),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            // Loading indicator
                            if (sosProvider.isLoading) ...[
                              const SizedBox(height: 20),
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0D1B6E),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, SOSProvider sosProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Ionicons.arrow_back, size: 24),
            onPressed: () => Navigator.pop(context),
            color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
          ),
          const SizedBox(width: 10),
          Text(
            'Emergency SOS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
