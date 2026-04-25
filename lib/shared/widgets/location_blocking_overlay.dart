import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import '../../core/providers/location_permission_provider.dart';

class LocationBlockingOverlay extends StatelessWidget {
  const LocationBlockingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Consumer<LocationPermissionProvider>(
      builder: (context, locationProvider, child) {
        // Don't show if everything is okay
        if (locationProvider.canUseApp) {
          return const SizedBox.shrink();
        }

        final isPermissionDenied = locationProvider.isPermissionDenied;
        final isGpsDisabled = locationProvider.isGpsDisabled;

        return Container(
          color: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Warning Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                    ),
                    child: const Icon(
                      Ionicons.warning,
                      size: 60,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Title
                  Text(
                    'Action Required',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Message
                  Text(
                    isPermissionDenied
                        ? 'SHEildAI requires "Always On" location permission to protect you. Without location access, we cannot provide safety alerts, route guidance, or emergency SOS features.'
                        : 'GPS is disabled. Please turn on location services to continue. SHEildAI needs your location to provide real-time safety features.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Enable Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: locationProvider.isLoading
                          ? null
                          : () async {
                              if (isGpsDisabled) {
                                await locationProvider.openLocationSettings();
                              } else {
                                await locationProvider.requestLocationPermission();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFdc2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      child: locationProvider.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Enable Now',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Retry Button
                  if (locationProvider.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        locationProvider.errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFdc2626),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
