import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  bool _zoneEntry = true;
  bool _community = true;
  bool _sosConf = true;
  bool _safetyCheck = true;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: theme.background,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(width: 40, height: 40, alignment: Alignment.centerLeft,
                      child: Icon(Icons.arrow_back_rounded, color: theme.textPrimary, size: 24)),
                  ),
                  Expanded(
                    child: Text(
                      lang.t('notification_prefs'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.t('alert_types').toUpperCase(),
                      style: TextStyle(color: theme.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                      ),
                      child: Column(
                        children: [
                          _buildToggleRow(
                            icon: Icons.location_on_rounded,
                            iconBg: const Color(0xFFE3F2FD),
                            iconColor: const Color(0xFF1976D2),
                            title: lang.t('zone_entry_alerts'),
                            subtitle: lang.t('zone_entry_desc'),
                            value: _zoneEntry,
                            onChanged: (v) => setState(() => _zoneEntry = v),
                            theme: theme,
                            isFirst: true,
                          ),
                          Divider(color: theme.border, height: 1, indent: 72),
                          _buildToggleRow(
                            icon: Icons.people_rounded,
                            iconBg: const Color(0xFFE8F5E9),
                            iconColor: const Color(0xFF388E3C),
                            title: lang.t('community_alerts'),
                            subtitle: lang.t('community_alerts_desc'),
                            value: _community,
                            onChanged: (v) => setState(() => _community = v),
                            theme: theme,
                          ),
                          Divider(color: theme.border, height: 1, indent: 72),
                          _buildToggleRow(
                            icon: Icons.shield_rounded,
                            iconBg: const Color(0xFFFFEBEE),
                            iconColor: const Color(0xFFC62828),
                            title: lang.t('sos_confirmation'),
                            subtitle: lang.t('sos_conf_desc'),
                            value: _sosConf,
                            onChanged: (v) => setState(() => _sosConf = v),
                            theme: theme,
                          ),
                          Divider(color: theme.border, height: 1, indent: 72),
                          _buildToggleRow(
                            icon: Icons.check_circle_rounded,
                            iconBg: const Color(0xFFF3E5F5),
                            iconColor: const Color(0xFF7B1FA2),
                            title: lang.t('safety_check_in'),
                            subtitle: lang.t('safety_check_desc'),
                            value: _safetyCheck,
                            onChanged: (v) => setState(() => _safetyCheck = v),
                            theme: theme,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeProvider theme,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
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
                Text(title, style: TextStyle(color: theme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF0D1B6E),
          ),
        ],
      ),
    );
  }
}
