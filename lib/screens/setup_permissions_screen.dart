import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';

/// Single-screen permission gate shown once after first login.
///
/// All runtime permissions are requested sequentially (Android requires
/// individual dialogs per permission group) but shown together on one screen
/// so the user understands why each is needed before tapping "Grant All".
/// After the request round, the user can proceed regardless of which
/// permissions were granted — the app degrades gracefully for denied ones.
class SetupPermissionsScreen extends StatefulWidget {
  const SetupPermissionsScreen({super.key});

  @override
  State<SetupPermissionsScreen> createState() => _SetupPermissionsScreenState();
}

class _SetupPermissionsScreenState extends State<SetupPermissionsScreen>
    with SingleTickerProviderStateMixin {
  bool _isRequesting = false;
  bool _requestComplete = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ─── Permission status map ─────────────────────────────────────────────────
  // null  = not yet requested
  // true  = granted
  // false = denied / permanently denied
  final Map<String, bool?> _status = {
    'location': null,
    'backgroundLocation': null,
    'camera': null,
    'microphone': null,
    'notifications': null,
    'sms': null,
    'phoneState': null,
    'battery': null,
  };

  // ─── Permission metadata ───────────────────────────────────────────────────
  static const _permMeta = [
    _PermMeta(
      key: 'location',
      icon: Icons.location_on_rounded,
      color: Color(0xFF4CAF50),
      title: 'Location',
      reason: 'Sends your live GPS coordinates to guardians during SOS.',
    ),
    _PermMeta(
      key: 'backgroundLocation',
      icon: Icons.my_location_rounded,
      color: Color(0xFF43A047),
      title: 'Background Location',
      reason: 'Keeps tracking your position even when the app is minimised.',
    ),
    _PermMeta(
      key: 'camera',
      icon: Icons.videocam_rounded,
      color: Color(0xFFFF9800),
      title: 'Camera',
      reason: 'Records video evidence automatically when SOS is triggered.',
    ),
    _PermMeta(
      key: 'microphone',
      icon: Icons.mic_rounded,
      color: Color(0xFFF44336),
      title: 'Microphone',
      reason: 'Enables voice trigger ("help") and audio recording during SOS.',
    ),
    _PermMeta(
      key: 'notifications',
      icon: Icons.notifications_rounded,
      color: Color(0xFF9C27B0),
      title: 'Notifications',
      reason: 'Delivers critical safety alerts and SOS status updates.',
    ),
    _PermMeta(
      key: 'sms',
      icon: Icons.chat_bubble_rounded,
      color: Color(0xFF1976D2),
      title: 'Send SMS',
      reason: 'Dispatches emergency text messages to your trusted contacts.',
    ),
    _PermMeta(
      key: 'phoneState',
      icon: Icons.phone_android_rounded,
      color: Color(0xFF00897B),
      title: 'Phone State',
      reason: 'Detects calls so SOS recordings are not interrupted.',
    ),
    _PermMeta(
      key: 'battery',
      icon: Icons.battery_charging_full_rounded,
      color: Color(0xFFE53935),
      title: 'Ignore Battery Limits',
      reason: 'Prevents Android from killing the SOS service when the screen is off or battery is low.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Check which permissions are already granted on entry.
    _checkExistingPermissions();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ─── Check existing state ──────────────────────────────────────────────────

  Future<void> _checkExistingPermissions() async {
    final results = await Future.wait([
      Permission.location.status,
      Permission.locationAlways.status,
      Permission.camera.status,
      Permission.microphone.status,
      Permission.notification.status,
      Permission.sms.status,
      Permission.phone.status,
      Permission.ignoreBatteryOptimizations.status,
    ]);

    if (!mounted) return;
    setState(() {
      _status['location']           = results[0].isGranted;
      _status['backgroundLocation'] = results[1].isGranted;
      _status['camera']             = results[2].isGranted;
      _status['microphone']         = results[3].isGranted;
      _status['notifications']      = results[4].isGranted;
      _status['sms']                = results[5].isGranted;
      _status['phoneState']         = results[6].isGranted;
      _status['battery']            = results[7].isGranted;
    });

    // If every runtime permission is already granted (e.g. returning user
    // whose setup_complete got cleared somehow), skip straight through.
    if (_status.values.every((v) => v == true)) {
      _requestComplete = true;
    }
  }

  // ─── Request all at once ───────────────────────────────────────────────────

  Future<void> _requestAll() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    // Android requires individual permission dialogs.
    // We request them in the order Android expects (coarse → fine → always,
    // then independent groups) so the user sees rational dialog sequences.
    try {
      // 1. Fine location (must be granted before background location)
      final locStatus = await Permission.locationWhenInUse.request();
      if (mounted) setState(() => _status['location'] = locStatus.isGranted);

      // 2. Background / always-on location (only ask if foreground was granted)
      if (locStatus.isGranted) {
        final bgStatus = await Permission.locationAlways.request();
        if (mounted) setState(() => _status['backgroundLocation'] = bgStatus.isGranted);
      } else {
        if (mounted) setState(() => _status['backgroundLocation'] = false);
      }

      // 3. Camera
      final camStatus = await Permission.camera.request();
      if (mounted) setState(() => _status['camera'] = camStatus.isGranted);

      // 4. Microphone
      final micStatus = await Permission.microphone.request();
      if (mounted) setState(() => _status['microphone'] = micStatus.isGranted);

      // 5. Notifications (Android 13+ only; no-op on older versions)
      if (Platform.isAndroid) {
        final notifStatus = await Permission.notification.request();
        if (mounted) setState(() => _status['notifications'] = notifStatus.isGranted);
      } else {
        if (mounted) setState(() => _status['notifications'] = true);
      }

      // 6. Send SMS
      final smsStatus = await Permission.sms.request();
      if (mounted) setState(() => _status['sms'] = smsStatus.isGranted);

      // 7. Phone state (READ_PHONE_STATE)
      final phoneStatus = await Permission.phone.request();
      if (mounted) setState(() => _status['phoneState'] = phoneStatus.isGranted);

      // 8. Ignore battery optimizations — critical for SOS background service
      //    survival on aggressive OEMs (MIUI, One UI, ColorOS, etc.).
      final batteryStatus = await Permission.ignoreBatteryOptimizations.request();
      if (mounted) setState(() => _status['battery'] = batteryStatus.isGranted);

    } catch (e) {
      debugPrint('[Permissions] Error during batch request: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
          _requestComplete = true;
        });
      }
    }
  }

  // ─── Finalize & proceed ────────────────────────────────────────────────────

  Future<void> _finish() async {
    final safety = context.read<SafetyProvider>();
    final updated = safety.userProfile.copyWith(isSetupComplete: true);
    await safety.updateUserProfile(updated);
    // AppBootstrap will automatically route to MainScreen once isSetupComplete = true.
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  int get _grantedCount => _status.values.where((v) => v == true).length;
  int get _totalCount   => _status.length;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? theme.background : const Color(0xFF0D1B6E),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _buildHeader(theme, isDark),
            // ── Scrollable body ─────────────────────────────────────────────
            Expanded(
              child: Container(
                color: isDark ? theme.background : const Color(0xFFF0F2FA),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Column(
                    children: [
                      // Progress badge
                      _buildProgressBadge(),
                      const SizedBox(height: 20),
                      // Permission cards
                      ..._permMeta.map((meta) => _buildPermCard(meta, theme, isDark)),
                      const SizedBox(height: 28),
                      // CTA button
                      _buildCTA(theme),
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

  Widget _buildHeader(ThemeProvider theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [theme.background, theme.background]
              : [const Color(0xFF0D1B6E), const Color(0xFF1a2c9e)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'SHEild AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Enable Your Shields',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Grant the permissions below so SHEild AI can protect you in every situation — foreground, background, or screen off.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBadge() {
    final granted = _grantedCount;
    final total   = _totalCount;
    final pct     = total == 0 ? 0 : (granted / total * 100).round();

    final color = granted == total
        ? const Color(0xFF43A047)
        : granted >= total ~/ 2
            ? const Color(0xFFF57C00)
            : const Color(0xFFD32F2F);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            granted == total ? Icons.verified_rounded : Icons.security_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  granted == total
                      ? 'Fully Protected 🛡️'
                      : '$granted / $total permissions granted',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : granted / total,
                    backgroundColor: color.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$pct% of safety features active',
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermCard(_PermMeta meta, ThemeProvider theme, bool isDark) {
    final status = _status[meta.key];
    final isGranted  = status == true;
    final isDenied   = status == false;
    final isPending  = status == null;

    final borderColor = isGranted
        ? const Color(0xFF43A047).withOpacity(0.4)
        : isDenied
            ? const Color(0xFFD32F2F).withOpacity(0.3)
            : meta.color.withOpacity(0.2);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? theme.surface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: meta.color.withOpacity(0.12),
            ),
            child: Icon(meta.icon, color: meta.color, size: 22),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.title,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  meta.reason,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Status indicator
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: isPending
                ? _isRequesting
                    ? SizedBox(
                        key: const ValueKey('loading'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: meta.color,
                        ),
                      )
                    : Icon(
                        key: const ValueKey('pending'),
                        Icons.radio_button_unchecked_rounded,
                        color: theme.textSecondary.withOpacity(0.4),
                        size: 24,
                      )
                : isGranted
                    ? const Icon(
                        key: ValueKey('granted'),
                        Icons.check_circle_rounded,
                        color: Color(0xFF43A047),
                        size: 24,
                      )
                    : const Icon(
                        key: ValueKey('denied'),
                        Icons.cancel_rounded,
                        color: Color(0xFFD32F2F),
                        size: 24,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTA(ThemeProvider theme) {
    if (_requestComplete) {
      // ── Post-request: show result + proceed button ──────────────────────────
      final allGranted = _grantedCount == _totalCount;
      return Column(
        children: [
          // Denied hint (only shown when some were denied)
          if (!allGranted)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFF57C00), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Some permissions were denied. You can grant them later in '
                      'Android Settings → App → Permissions. The app will work '
                      'but some safety features may be limited.',
                      style: TextStyle(
                        color: Colors.brown.shade700,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Proceed button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _finish,
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              label: Text(
                allGranted ? 'All Set — Enter App' : 'Continue Anyway',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: allGranted
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF0D1B6E),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
            ),
          ),
          // Open settings shortcut
          if (!allGranted) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: openAppSettings,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Open App Settings to grant denied permissions',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    // ── Pre-request: "Grant All Permissions" pulsing button ──────────────────
    return ScaleTransition(
      scale: _isRequesting ? const AlwaysStoppedAnimation(1.0) : _pulseAnimation,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isRequesting ? null : _requestAll,
          icon: _isRequesting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : const Icon(Icons.security_rounded, color: Colors.white, size: 22),
          label: Text(
            _isRequesting ? 'Requesting…' : 'Grant All Permissions',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D1B6E),
            disabledBackgroundColor: const Color(0xFF0D1B6E).withOpacity(0.6),
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            shadowColor: const Color(0xFF0D1B6E).withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}

// ─── Metadata model ────────────────────────────────────────────────────────────

class _PermMeta {
  final String key;
  final IconData icon;
  final Color color;
  final String title;
  final String reason;

  const _PermMeta({
    required this.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.reason,
  });
}
