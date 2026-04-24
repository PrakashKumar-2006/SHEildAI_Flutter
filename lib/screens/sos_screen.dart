import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';
import '../widgets/notification_bell_popup.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _recPulse;
  late Animation<double> _sessionGlow;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..repeat(reverse: true);
    _recPulse = Tween<double>(begin: 1.0, end: 1.45).animate(_pulseController);
    _sessionGlow = Tween<double>(begin: 0.7, end: 1.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatSessionStart(DateTime? dt) {
    if (dt == null) return 'Acquiring...';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatShortId(String? id) {
    if (id == null || id.isEmpty) return '#SYSTEM-ACTIVE';
    return '#${id.substring(id.length > 8 ? id.length - 8 : 0).toUpperCase()}';
  }

  Color get _riskColor {
    final safety = context.read<SafetyProvider>();
    switch (safety.riskLabel) {
      case 'CRITICAL': return const Color(0xFF8B0000);
      case 'HIGH': return const Color(0xFFdc2626);
      case 'MEDIUM': return const Color(0xFFd97706);
      default: return const Color(0xFF43A047);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();
    final safety = context.watch<SafetyProvider>();
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? theme.background : const Color(0xFF0D1B6E),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(theme, lang, isDark),
            // Content
            Expanded(
              child: Container(
                color: isDark ? theme.background : const Color(0xFFF0F2FA),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Risk banner
                      _buildRiskBanner(safety, lang),
                      const SizedBox(height: 14),
                      // SOS Status banner
                      _buildSOSStatusBanner(safety, lang),
                      const SizedBox(height: 14),
                      // Main panel
                      safety.isSOSActive
                          ? _buildSessionPanel(safety, lang, theme, isDark)
                          : _buildIdlePanel(safety, lang, theme, isDark),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider theme, LanguageProvider lang, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [theme.background, theme.background]
              : [const Color(0xFF0D1B6E), const Color(0xFF1a2c9e)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.shield_outlined, color: Color(0xFF7EB8FF), size: 20),
          const SizedBox(width: 6),
          Text(
            lang.t('shield_ai'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          const NotificationBellPopup(iconColor: Colors.white),
        ],
      ),
    );
  }

  Widget _buildRiskBanner(SafetyProvider safety, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _riskColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            safety.riskLabel == 'SAFE' ? Icons.shield_rounded : Icons.warning_rounded,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(
            '  ${safety.riskLabel}  ·  ${safety.readableAddress}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSStatusBanner(SafetyProvider safety, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: safety.isSOSActive ? const Color(0xFFC62828) : const Color(0xFF43A047),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            safety.isSOSActive ? Icons.warning_rounded : Icons.shield_rounded,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            safety.isSOSActive ? lang.t('sos_active') : lang.t('sos_idle'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionPanel(SafetyProvider safety, LanguageProvider lang, ThemeProvider theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.surface : const Color(0xFF0D1B6E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1B6E).withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _sessionGlow,
                  builder: (_, __) => Opacity(
                    opacity: _sessionGlow.value,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF3B30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lang.t('active_session'),
                    style: const TextStyle(
                      color: Color(0xFFFF6B6B),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatShortId(safety.sosSessionId),
                    style: const TextStyle(
                      color: Color(0xFF7EB8FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Meta row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                _buildMetaItem(
                  Icons.access_time_rounded,
                  lang.t('started'),
                  _formatSessionStart(safety.sosSessionStart),
                ),
                Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
                _buildMetaItem(
                  Icons.timer_outlined,
                  lang.t('duration'),
                  _formatDuration(safety.activeSessionDuration),
                ),
                Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
                _buildMetaItem(
                  Icons.location_on_outlined,
                  lang.t('location'),
                  '${safety.latitude.toStringAsFixed(3)}, ${safety.longitude.toStringAsFixed(3)}',
                ),
              ],
            ),
          ),
          // Recording / SOS panel
          if (safety.sosState == 'RECORDING') _buildRecPanel(safety, lang),
          if (safety.sosState == 'SOS_ACTIVE') _buildSOSActivePanel(safety, lang),
          if (safety.sosState == 'RECOVERING') _buildRecDonePanel(lang),
          // I'm Safe button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: GestureDetector(
              onTap: safety.confirmSafe,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF2E7D32).withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang.t('i_am_safe_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          lang.t('i_am_safe_sub'),
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Text(
              lang.t('i_am_safe_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF7EB8FF), size: 14),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildRecPanel(SafetyProvider safety, LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _recPulse,
                builder: (_, __) => Transform.scale(
                  scale: _recPulse.value,
                  child: Container(
                    width: 10, height: 10,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF3B30)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text('REC', style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
              const SizedBox(width: 6),
              const Icon(Icons.videocam_rounded, color: Color(0xFFFF3B30), size: 13),
              const SizedBox(width: 4),
              Text('  ${lang.t('capturing_evidence')}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang.t('auto_stop_in'), style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10, letterSpacing: 1)),
                  Text(
                    _formatDuration(safety.recordingTimeLeft),
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: safety.stopRecording,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFC62828), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.stop_circle_outlined, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(lang.t('stop_recording'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSOSActivePanel(SafetyProvider safety, LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF7EB8FF).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7EB8FF).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.sync_rounded, color: Color(0xFF7EB8FF), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lang.t('sos_active_init'),
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: safety.confirmSafe,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF0D47A1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cancel_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(lang.t('stop_sos_button'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecDonePanel(LanguageProvider lang) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF43A047).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF43A047).withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outlined, color: Color(0xFF43A047), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lang.t('rec_done_text'),
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdlePanel(SafetyProvider safety, LanguageProvider lang, ThemeProvider theme, bool isDark) {
    return Column(
      children: [
        // Trigger SOS card
        GestureDetector(
          onTap: safety.triggerSOSFlow,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B0000), Color(0xFFCC0000), Color(0xFFFF3B30)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF0000).withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 8)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
            child: Column(
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  lang.t('trigger_sos'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  lang.t('trigger_sos_sub'),
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.videocam_outlined, color: Color(0xAAFFFFFF), size: 13),
                    Text(
                      '  ${lang.t('trigger_sos_meta1')}',
                      style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const Text('  ·  ', style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 11)),
                    const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xAAFFFFFF), size: 13),
                    Text(
                      '  ${lang.t('trigger_sos_meta2')}',
                      style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Idle info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: theme.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.5),
                    children: [
                      TextSpan(text: lang.t('no_active_session') + ' '),
                      TextSpan(
                        text: lang.t('trigger_sos_cta'),
                        style: TextStyle(fontWeight: FontWeight.w800, color: theme.textPrimary),
                      ),
                      TextSpan(text: ' ' + lang.t('no_active_session2')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
