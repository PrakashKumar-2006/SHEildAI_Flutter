import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';
import '../widgets/notification_bell_popup.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _showReportModal = false;
  String _reportType = 'Suspicious person following';
  final TextEditingController _descController = TextEditingController();
  int _severity = 5;
  bool _submitting = false;

  final List<String> _incidentTypes = [
    'Suspicious person following',
    'Harassment',
    'Poorly lit area',
    'Isolated road',
    'Drug activity',
    'Vehicle following',
    'Unsafe street vendor area',
    'Other',
  ];

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final lang = context.read<LanguageProvider>();
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a brief description.')),
      );
      return;
    }
    setState(() => _submitting = true);
    final safety = context.read<SafetyProvider>();
    final success = await safety.submitCommunityReport(_reportType, _descController.text.trim(), _severity);
    if (mounted) {
      setState(() => _submitting = false);
      if (success) {
        setState(() => _showReportModal = false);
        _descController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report shared anonymously with community.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();
    final safety = context.watch<SafetyProvider>();
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(theme, lang),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Report Observation card
                        _buildObservationCard(theme, lang),
                        // Alert feed
                        _buildAlertFeed(theme, lang, safety, isDark),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Floating SOS button
            Positioned(
              bottom: 20,
              right: 20,
              child: GestureDetector(
                onTap: safety.isSOSActive ? safety.confirmSafe : safety.triggerSOSFlow,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: safety.isSOSActive
                          ? [const Color(0xFF1B5E20), const Color(0xFF43A047)]
                          : [const Color(0xFFCC0000), const Color(0xFFFF0000)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (safety.isSOSActive ? const Color(0xFF43A047) : const Color(0xFFFF0000)).withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    safety.isSOSActive ? Icons.shield_rounded : Icons.navigation_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            // Report modal
            if (_showReportModal) _buildReportModal(theme, lang, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider theme, LanguageProvider lang) {
    return Container(
      color: theme.background,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: theme.surface, shape: BoxShape.circle),
            child: Icon(Icons.person_rounded, color: theme.textPrimary, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            lang.t('shield_ai'),
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          NotificationBellPopup(iconColor: theme.textPrimary),
        ],
      ),
    );
  }

  Widget _buildObservationCard(ThemeProvider theme, LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF1976D2), size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            lang.t('report_observation'),
            style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            lang.t('help_others_msg'),
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => setState(() => _showReportModal = true),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.accent, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              lang.t('report_now'),
              style: TextStyle(color: theme.accent, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertFeed(ThemeProvider theme, LanguageProvider lang, SafetyProvider safety, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('safety_alert_feed'),
            style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (safety.alerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064e3b) : const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shield_rounded, color: isDark ? const Color(0xFF34d399) : const Color(0xFF2E7D32), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.t('system_vigilant'), style: const TextStyle(color: Color(0xFF43A047), fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(lang.t('no_alerts'), style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ...safety.alerts.map((alert) => _buildAlertCard(alert, theme, isDark)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(AlertItem alert, ThemeProvider theme, bool isDark) {
    final isSOS = alert.type == 'SOS';
    final isSafe = alert.type == 'SAFE';
    final isReport = alert.type == 'REPORT';

    final accentColor = isSafe ? const Color(0xFF2E7D32)
        : isSOS ? const Color(0xFFC62828)
        : isReport ? const Color(0xFFE65100)
        : alert.riskLevel == 'CRITICAL' ? const Color(0xFF8B0000)
        : alert.riskLevel == 'HIGH' ? const Color(0xFFE65100) : const Color(0xFFF57C00);

    final iconBg = isSafe ? const Color(0xFFE8F5E9)
        : isSOS ? const Color(0xFFFFEBEE)
        : isReport ? const Color(0xFFFFF3E0)
        : const Color(0xFFFFEBEE);

    final iconName = isSafe ? Icons.shield_rounded
        : isSOS ? Icons.campaign_rounded
        : isReport ? Icons.remove_red_eye_rounded : Icons.warning_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? accentColor.withOpacity(0.2) : iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(iconName, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: TextStyle(color: theme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(alert.body, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportModal(ThemeProvider theme, LanguageProvider lang, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _showReportModal = false),
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () {}, // prevent tap-through
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Row(
                        children: [
                          Text('Community Alert', style: TextStyle(color: theme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _showReportModal = false),
                            child: Icon(Icons.close_rounded, color: theme.textSecondary, size: 24),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Incident Type', style: TextStyle(color: theme.textSecondary, fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _incidentTypes.map((type) => GestureDetector(
                                onTap: () => setState(() => _reportType = type),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _reportType == type ? theme.accent : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: _reportType == type ? theme.accent : theme.border),
                                  ),
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      color: _reportType == type ? Colors.white : theme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: _reportType == type ? FontWeight.w700 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              )).toList(),
                            ),
                            const SizedBox(height: 16),
                            Text('Description', style: TextStyle(color: theme.textSecondary, fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.border),
                              ),
                              child: TextField(
                                controller: _descController,
                                maxLines: 4,
                                style: TextStyle(color: theme.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'What did you see?',
                                  hintStyle: TextStyle(color: theme.textSecondary),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text('Severity ($_severity/10)', style: TextStyle(color: theme.textSecondary, fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(10, (i) => GestureDetector(
                                onTap: () => setState(() => _severity = i + 1),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _severity >= i + 1
                                        ? (i + 1 > 7 ? const Color(0xFFC62828) : i + 1 > 4 ? const Color(0xFFE65100) : const Color(0xFF43A047))
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE0E0E0)),
                                  ),
                                ),
                              )),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1e293b) : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_rounded, color: theme.textSecondary, size: 14),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Your report is 100% anonymous.',
                                      style: TextStyle(color: theme.textSecondary, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitting ? null : _submitReport,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.accent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  _submitting ? 'Submitting...' : 'Post Community Alert',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
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
}
