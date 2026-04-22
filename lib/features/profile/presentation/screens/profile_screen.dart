import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/card_widget.dart';
import '../../../../shared/widgets/custom_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: const CustomAppBar(
        title: 'Profile',
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: AppTheme.spacingL),
            // Profile Header
            _buildProfileHeader(),
            const SizedBox(height: AppTheme.spacingL),
            // Emergency Contacts
            _buildEmergencyContacts(context),
            const SizedBox(height: AppTheme.spacingM),
            // Settings
            _buildSettings(context),
            const SizedBox(height: AppTheme.spacingL),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return CardWidget(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        children: [
          // Profile Picture
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 50,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Name
          const Text(
            'User Name',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXS),
          // Phone
          Text(
            '+91 98765 43210',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Edit Button
          CustomButton(
            text: 'Edit Profile',
            isOutlined: true,
            onPressed: () {
              // TODO: Implement edit profile
            },
            width: 150,
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContacts(BuildContext context) {
    return CardWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Emergency Contacts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Implement add contact
                },
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Contact 1
          _buildContactItem(
            name: 'Father',
            phone: '+91 98765 43211',
          ),
          const Divider(),
          // Contact 2
          _buildContactItem(
            name: 'Mother',
            phone: '+91 98765 43212',
          ),
          const Divider(),
          // Contact 3
          _buildContactItem(
            name: 'Sister',
            phone: '+91 98765 43213',
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required String name,
    required String phone,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call),
            color: AppColors.primary,
            onPressed: () {
              // TODO: Implement call
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettings(BuildContext context) {
    return CardWidget(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildSettingItem(
            icon: Icons.notifications,
            title: 'Notifications',
            onTap: () {
              // TODO: Implement notifications settings
            },
          ),
          const Divider(),
          _buildSettingItem(
            icon: Icons.location_on,
            title: 'Location Settings',
            onTap: () {
              // TODO: Implement location settings
            },
          ),
          const Divider(),
          _buildSettingItem(
            icon: Icons.mic,
            title: 'Voice Settings',
            onTap: () {
              // TODO: Implement voice settings
            },
          ),
          const Divider(),
          _buildSettingItem(
            icon: Icons.security,
            title: 'Privacy & Security',
            onTap: () {
              // TODO: Implement privacy settings
            },
          ),
          const Divider(),
          _buildSettingItem(
            icon: Icons.help,
            title: 'Help & Support',
            onTap: () {
              // TODO: Implement help
            },
          ),
          const Divider(),
          _buildSettingItem(
            icon: Icons.info,
            title: 'About',
            onTap: () {
              // TODO: Implement about
            },
          ),
          const SizedBox(height: AppTheme.spacingM),
          // Logout
          CustomButton(
            text: 'Logout',
            backgroundColor: AppColors.error,
            onPressed: () {
              // TODO: Implement logout
            },
            width: double.infinity,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusS),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
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
}
