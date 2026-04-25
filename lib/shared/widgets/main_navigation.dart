import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ionicons/ionicons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/routes/presentation/screens/routes_screen.dart';
import '../../features/alerts/presentation/screens/alerts_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/sos/presentation/screens/sos_screen.dart';
import '../../features/home/presentation/providers/home_provider.dart';
import '../../features/sos/presentation/providers/sos_provider.dart';

class MainNavigation extends StatelessWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<HomeProvider, SOSProvider>(
      builder: (context, homeProvider, sosProvider, child) {
        final isSOSActive = sosProvider.isSOSActive;
        
        return Scaffold(
          body: IndexedStack(
            index: homeProvider.currentIndex,
            children: const [
              HomeScreen(),
              RoutesScreen(),
              SOSScreen(),
              AlertsScreen(),
              ProfileScreen(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? const Color(0xFF0F172A) 
                  : AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM,
                  vertical: AppTheme.spacingS,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      icon: Ionicons.home,
                      label: 'HOME',
                      isSelected: homeProvider.currentIndex == 0,
                      onTap: () => homeProvider.setIndex(0),
                      context: context,
                    ),
                    _buildNavItem(
                      icon: Ionicons.map,
                      label: 'ROUTES',
                      isSelected: homeProvider.currentIndex == 1,
                      onTap: () => homeProvider.setIndex(1),
                      context: context,
                    ),
                    // SOS Button - Center Special Button
                    _buildSOSButton(
                      isSOSActive: isSOSActive,
                      onTap: () => homeProvider.setIndex(2),
                      context: context,
                    ),
                    _buildNavItem(
                      icon: Ionicons.notifications,
                      label: 'ALERTS',
                      isSelected: homeProvider.currentIndex == 3,
                      onTap: () => homeProvider.setIndex(3),
                      context: context,
                    ),
                    _buildNavItem(
                      icon: Ionicons.person,
                      label: 'PROFILE',
                      isSelected: homeProvider.currentIndex == 4,
                      onTap: () => homeProvider.setIndex(4),
                      context: context,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 48 : 44,
              height: isSelected ? 48 : 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected 
                    ? AppColors.primary 
                    : (isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Icon(
                icon,
                color: isSelected 
                    ? Colors.white 
                    : (isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected 
                    ? AppColors.primary 
                    : (isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSOSButton({
    required bool isSOSActive,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Outer ring with gradient
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSOSActive 
                    ? const LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFCC0000), Color(0xFFFF0000), Color(0xFFFF4D4D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: isSOSActive 
                        ? const Color(0xFF43A047).withValues(alpha: 0.5)
                        : const Color(0xFFFF0000).withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  isSOSActive ? Ionicons.shield_checkmark : Ionicons.shield,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'SOS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isSOSActive 
                    ? const Color(0xFF1B5E20)
                    : (isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Consumer2 helper widget
class Consumer2<A, B> extends StatelessWidget {
  final Widget Function(BuildContext context, A a, B b, Widget? child) builder;
  final Widget? child;
  
  const Consumer2({super.key, required this.builder, this.child});
  
  @override
  Widget build(BuildContext context) {
    return Consumer<A>(
      builder: (context, a, _) => Consumer<B>(
        builder: (context, b, _) => builder(context, a, b, child),
      ),
    );
  }
}
