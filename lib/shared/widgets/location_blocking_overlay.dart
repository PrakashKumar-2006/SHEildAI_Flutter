import 'package:flutter/material.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:provider/provider.dart';
import '../../core/providers/location_permission_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../providers/providers.dart' show SafetyProvider;

class LocationBlockingOverlay extends StatelessWidget {
  const LocationBlockingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final authProvider = context.watch<AuthProvider>();
    final safetyProvider = context.watch<SafetyProvider>();
    final locationProvider = context.watch<LocationPermissionProvider>();

    // Don't show if user is not logged in yet
    if (!authProvider.isAuthenticated) {
      return const SizedBox.shrink();
    }

    // Don't show if everything is okay or still checking
    if (locationProvider.canUseApp || 
        locationProvider.permissionStatus == PermissionStatus.checking || 
        locationProvider.gpsStatus == GpsStatus.checking) {
      return const SizedBox.shrink();
    }

    final isBlocked = locationProvider.permissionStatus == PermissionStatus.blocked;
    final isGpsDisabled = locationProvider.isGpsDisabled;

    String title;
    String message;
    String buttonLabel;
    IconData icon;
    Color accentColor;
    VoidCallback onPressed;

    if (isGpsDisabled) {
      title = 'GPS is Turned Off';
      message = 'Your device location (GPS) is disabled. SHEildAI requires real-time location to monitor your safety and trigger alerts if you enter danger zones.';
      buttonLabel = 'Enable GPS Service';
      icon = Ionicons.location_outline;
      accentColor = const Color(0xFFF59E0B); // Amber
      onPressed = () => locationProvider.openLocationSettings();
    } else if (isBlocked) {
      title = 'Permission Blocked';
      message = 'Location access was permanently denied. Please go to your device settings and set Location permission to "Allow all the time" for SHEildAI.';
      buttonLabel = 'Open App Settings';
      icon = Ionicons.settings_outline;
      accentColor = const Color(0xFFEF4444); // Red
      onPressed = () => locationProvider.openAppSettings();
    } else {
      title = 'Location Required';
      message = 'To keep you safe, SHEildAI needs "Always On" location access. This allows the app to detect emergencies even when your phone is in your pocket.';
      buttonLabel = 'Grant Access';
      icon = Ionicons.shield_checkmark_outline;
      accentColor = const Color(0xFF3B82F6); // Blue
      onPressed = () => locationProvider.requestLocationPermission();
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.7), // Semi-transparent backdrop
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with animated-like feel
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.1),
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Primary Action Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: locationProvider.isLoading ? null : onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: locationProvider.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          buttonLabel,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Secondary Action: Manual Refresh
              TextButton.icon(
                onPressed: () => locationProvider.refreshStatus(),
                icon: const Icon(Ionicons.refresh_outline, size: 18),
                label: const Text('Re-check Status'),
                style: TextButton.styleFrom(
                  foregroundColor: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                ),
              ),
              
              if (locationProvider.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    locationProvider.errorMessage!,
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
