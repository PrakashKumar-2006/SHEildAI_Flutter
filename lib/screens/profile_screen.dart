import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import 'personal_info_screen.dart';
import 'sos_contacts_screen.dart';
import 'language_screen.dart';
import 'notifications_settings_screen.dart';
import 'paywall_screen.dart';
import '../core/services/storage_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();
    final safety = context.watch<SafetyProvider>();
    final isDark = theme.isDarkMode;
    final isModal = ModalRoute.of(context)?.settings?.name != null;

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: theme.background,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : null,
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.centerLeft,
                      child: Icon(Icons.arrow_back_rounded, color: theme.textPrimary, size: 24),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      lang.t('profile_title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  children: [
                    // Profile card
                    _buildProfileCard(context, theme, lang, safety, isDark),
                    const SizedBox(height: 24),
                    // Account settings
                    _buildSection(
                      lang.t('account_settings'),
                      [
                        _OptionItem(
                          icon: Icons.person_rounded,
                          iconBg: const Color(0xFFF3E5F5),
                          iconColor: const Color(0xFF7B1FA2),
                          label: lang.t('personal_information'),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalInfoScreen())),
                          theme: theme,
                        ),
                        _OptionItem(
                          icon: Icons.star_rounded,
                          iconBg: const Color(0xFFE8F5E9),
                          iconColor: const Color(0xFF4CAF50),
                          label: 'Subscription & Plans',
                          subtitle: 'Free Plan',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen())),
                          theme: theme,
                        ),
                        _OptionItem(
                          icon: Icons.favorite_rounded,
                          iconBg: const Color(0xFFFFE5E5),
                          iconColor: const Color(0xFFFF0000),
                          label: lang.t('sos_guardians'),
                          subtitle: '${safety.trustedContacts.length} ${lang.t('contacts_active')}',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SOSContactsScreen())),
                          theme: theme,
                        ),
                      ],
                      theme,
                      lang,
                    ),
                    const SizedBox(height: 24),
                    // App preferences
                    _buildSection(
                      lang.t('app_preferences'),
                      [
                        _OptionItem(
                          icon: Icons.notifications_rounded,
                          iconBg: const Color(0xFFE3F2FD),
                          iconColor: const Color(0xFF1976D2),
                          label: lang.t('safety_notifications'),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen())),
                          theme: theme,
                        ),
                        _OptionItem(
                          icon: Icons.language_rounded,
                          iconBg: const Color(0xFFFFF8E1),
                          iconColor: const Color(0xFFFF8F00),
                          label: lang.t('app_language'),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageScreen())),
                          theme: theme,
                        ),
                        _OptionItem(
                          icon: Icons.shield_rounded,
                          iconBg: const Color(0xFFE4F8F4),
                          iconColor: const Color(0xFF009688),
                          label: 'System Permissions',
                          onTap: () {
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Manage Permissions')));
                          },
                          theme: theme,
                        ),
                      ],
                      theme,
                      lang,
                    ),
                    // Dark mode row
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EAF6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                              color: const Color(0xFF3F51B5),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              isDark ? lang.t('dark_mode') : lang.t('light_mode'),
                              style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                          Switch(
                            value: isDark,
                            onChanged: (_) => context.read<ThemeProvider>().toggleTheme(),
                            activeColor: const Color(0xFF3F51B5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Return home / logout btn
                    GestureDetector(
                      onTap: () async {
                        final auth = context.read<AuthProvider>();
                        final safety = context.read<SafetyProvider>();
                        
                        await safety.clearProfile();
                        await auth.signOut();
                        
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF451a1a) : const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded, color: Color(0xFFD32F2F), size: 20),
                            const SizedBox(width: 12),
                            const Text(
                              'Logout Account',
                              style: TextStyle(
                                color: Color(0xFFD32F2F),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

  Widget _buildProfileCard(BuildContext context, ThemeProvider theme, LanguageProvider lang, SafetyProvider safety, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF0D1B6E), Color(0xFF1976D2)],
              ),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 50),
          ),
          const SizedBox(height: 16),
          Text(
            safety.userProfile.name.isNotEmpty 
                ? safety.userProfile.name 
                : (context.read<AuthProvider>().user?.displayName ?? 
                   (context.read<StorageService>().getUserName() != 'Safety Watcher' 
                       ? context.read<StorageService>().getUserName() 
                       : (context.read<AuthProvider>().user?.email?.split('@')[0] ?? 'User'))),
            style: TextStyle(color: theme.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${lang.t('status_label')}: ${safety.riskLabel} ${lang.t('risk_label')}',
            style: TextStyle(color: theme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          Divider(color: theme.border),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${safety.riskScore}%',
                      style: TextStyle(color: theme.accent, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(lang.t('risk_level_stat'), style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: theme.border),
              Expanded(
                child: Column(
                  children: [
                    Text(lang.t('active'), style: TextStyle(color: theme.accent, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(lang.t('security_model'), style: TextStyle(color: theme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items, ThemeProvider theme, LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ...items,
      ],
    );
  }
}

class _OptionItem extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final ThemeProvider theme;

  const _OptionItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.subtitle,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
