import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ionicons/ionicons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/routes/presentation/screens/routes_screen.dart';
import '../../features/alerts/presentation/screens/alerts_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/home/presentation/providers/home_provider.dart';

class MainNavigation extends StatelessWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, child) {
        return Scaffold(
          body: IndexedStack(
            index: homeProvider.currentIndex,
            children: [
              const HomeScreen(),
              const RoutesScreen(),
              const AlertsScreen(),
              const ProfileScreen(),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
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
                      label: 'Home',
                      isSelected: homeProvider.currentIndex == 0,
                      onTap: () => homeProvider.setIndex(0),
                    ),
                    _buildNavItem(
                      icon: Ionicons.navigate,
                      label: 'Routes',
                      isSelected: homeProvider.currentIndex == 1,
                      onTap: () => homeProvider.setIndex(1),
                    ),
                    _buildNavItem(
                      icon: Ionicons.notifications,
                      label: 'Alerts',
                      isSelected: homeProvider.currentIndex == 2,
                      onTap: () => homeProvider.setIndex(2),
                    ),
                    _buildNavItem(
                      icon: Ionicons.person,
                      label: 'Profile',
                      isSelected: homeProvider.currentIndex == 3,
                      onTap: () => homeProvider.setIndex(3),
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingL,
          vertical: AppTheme.spacingS,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.grey500,
              size: 24,
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.grey500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
