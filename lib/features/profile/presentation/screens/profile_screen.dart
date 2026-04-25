import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isDarkMode = false;
  int _contactCount = 0;

  @override
  void initState() {
    super.initState();
    _loadContactCount();
  }

  Future<void> _loadContactCount() async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList('trusted_contacts');
    if (mounted) {
      setState(() {
        _contactCount = contacts?.length ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Profile Card
                    _buildProfileCard(context),
                    const SizedBox(height: 24),
                    // Account Settings
                    _buildSection(context, 'Account Settings', [
                      _buildOptionItem(
                        context,
                        icon: Ionicons.person,
                        iconColor: const Color(0xFF7B1FA2),
                        iconBg: const Color(0xFFF3E5F5),
                        title: 'Personal Information',
                        onTap: () {},
                      ),
                      _buildOptionItem(
                        context,
                        icon: Ionicons.star,
                        iconColor: const Color(0xFF4CAF50),
                        iconBg: const Color(0xFFE8F5E9),
                        title: 'Subscription & Plans',
                        subtitle: 'Free Plan',
                        onTap: () {},
                      ),
                      _buildOptionItem(
                        context,
                        icon: Ionicons.heart,
                        iconColor: const Color(0xFFFF0000),
                        iconBg: const Color(0xFFFFE5E5),
                        title: 'SOS Guardians',
                        subtitle: '$_contactCount contacts active',
                        onTap: () async {
                          await Navigator.pushNamed(context, '/manage_contacts');
                          _loadContactCount(); // Refresh count after returning
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),
                    // App Preferences
                    _buildSection(context, 'App Preferences', [
                      _buildOptionItem(
                        context,
                        icon: Ionicons.notifications,
                        iconColor: const Color(0xFF1976D2),
                        iconBg: const Color(0xFFE3F2FD),
                        title: 'Safety Notifications',
                        onTap: () {},
                      ),
                      _buildOptionItem(
                        context,
                        icon: Ionicons.language,
                        iconColor: const Color(0xFFFF8F00),
                        iconBg: const Color(0xFFFFF8E1),
                        title: 'App Language',
                        onTap: () {},
                      ),
                      _buildOptionItem(
                        context,
                        icon: Ionicons.shield_checkmark,
                        iconColor: const Color(0xFF009688),
                        iconBg: const Color(0xFFE4F8F4),
                        title: 'System Permissions',
                        onTap: () {},
                      ),
                      _buildThemeToggle(context),
                    ]),
                    const SizedBox(height: 24),
                    // Return Home Button
                    _buildReturnHomeButton(context),
                    const SizedBox(height: 40),
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
        children: [
          IconButton(
            icon: const Icon(Ionicons.arrow_back, size: 24),
            onPressed: () => Navigator.pop(context),
            color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
          ),
          const SizedBox(width: 10),
          Text(
            'Profile',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _isDarkMode ? Colors.white : const Color(0xFF0D1B6E),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D1B6E), Color(0xFF1976D2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Ionicons.person,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            'Safety Watcher',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 4),
          // Status
          Text(
            'Status: SAFE Risk',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 20),
          // Stats
          Container(
            padding: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFF0F0F0),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '85%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0D1B6E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Risk Level',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: _isDarkMode ? const Color(0xFF334155) : const Color(0xFFE0E0E0),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0D1B6E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Security Model',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF9E9E9E),
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

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF9E9E9E),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildOptionItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF757575),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Arrow
            Icon(
              Ionicons.chevron_forward,
              size: 20,
              color: _isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF9E9E9E),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isDarkMode ? Ionicons.moon : Ionicons.sunny,
              size: 20,
              color: const Color(0xFF3F51B5),
            ),
          ),
          const SizedBox(width: 16),
          // Text
          Expanded(
            child: Text(
              _isDarkMode ? 'Dark Mode' : 'Light Mode',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _isDarkMode ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ),
          // Switch
          Switch(
            value: _isDarkMode,
            onChanged: (value) {
              // TODO: Implement theme toggle
            },
            activeTrackColor: const Color(0xFF3F51B5),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnHomeButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1e3a8a) : const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Ionicons.log_out_outline,
              size: 20,
              color: _isDarkMode ? const Color(0xFF60a5fa) : const Color(0xFF1976D2),
            ),
            const SizedBox(width: 8),
            Text(
              'Return Home',
              style: TextStyle(
                color: _isDarkMode ? const Color(0xFF60a5fa) : const Color(0xFF1976D2),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
