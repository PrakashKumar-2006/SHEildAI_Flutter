import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/sos_button.dart';
import '../../../../shared/widgets/status_indicator.dart';
import '../providers/home_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Consumer<HomeProvider>(
          builder: (context, homeProvider, child) {
            return Column(
              children: [
                // App Bar
                _buildAppBar(context),
                // Main Content
                Expanded(
                  child: Column(
                    children: [
                      const Spacer(),
                      // Status Indicator
                      _buildStatusIndicator(homeProvider),
                      const SizedBox(height: AppTheme.spacingXL),
                      // SOS Button
                      SOSButton(
                        onPressed: () {
                          homeProvider.toggleSOS();
                        },
                        isActive: homeProvider.isSOSActive,
                        size: 220,
                      ),
                      const SizedBox(height: AppTheme.spacingXL),
                      // Quick Actions
                      _buildQuickActions(context, homeProvider),
                      const Spacer(),
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

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App Name
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SHEild AI',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXS),
              Text(
                'Your Safety, Our Priority',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          // Profile Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(HomeProvider homeProvider) {
    return StatusIndicator(
      status: homeProvider.isSOSActive
          ? StatusType.emergency
          : StatusType.safe,
      message: homeProvider.isSOSActive
          ? 'Emergency Mode Active'
          : 'You are Safe',
    );
  }

  Widget _buildQuickActions(BuildContext context, HomeProvider homeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
      child: Column(
        children: [
          // Share Location
          _buildQuickAction(
            context,
            icon: Icons.share_location,
            label: 'Share Location',
            onTap: () {
              // TODO: Implement share location
            },
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Call Emergency
          _buildQuickAction(
            context,
            icon: Icons.phone_in_talk,
            label: 'Call Emergency',
            onTap: () {
              _showEmergencyDialog(context);
            },
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Voice Mode
          _buildQuickAction(
            context,
            icon: homeProvider.isVoiceModeEnabled
                ? Icons.mic
                : Icons.mic_off,
            label: 'Voice Mode',
            onTap: () {
              homeProvider.toggleVoiceMode();
            },
            isActive: homeProvider.isVoiceModeEnabled,
          ),
          const SizedBox(height: AppTheme.spacingXL),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingL,
          vertical: AppTheme.spacingM,
        ),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryContainer : AppColors.grey100,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.grey400,
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Numbers'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildEmergencyNumber(context, 'Police', '100'),
            const SizedBox(height: AppTheme.spacingS),
            _buildEmergencyNumber(context, 'Women Helpline', '1091'),
            const SizedBox(height: AppTheme.spacingS),
            _buildEmergencyNumber(context, 'Ambulance', '102'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyNumber(BuildContext context, String label, String number) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppTheme.spacingS),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.phone,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(number),
      trailing: IconButton(
        icon: const Icon(Icons.call),
        color: AppColors.primary,
        onPressed: () {
          // TODO: Implement call functionality
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Calling $label: $number')),
          );
        },
      ),
    );
  }
}
