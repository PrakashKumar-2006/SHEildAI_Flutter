import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../features/sos/presentation/providers/sos_provider.dart';
import '../features/voice/presentation/providers/voice_provider.dart';
import 'home_screen.dart';
import '../features/routes/presentation/screens/routes_screen.dart';
import 'sos_screen.dart';
import 'alerts_screen.dart';
import 'profile_screen.dart';
import '../core/providers/location_permission_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  late AnimationController _sosAnimController;
  // Expose currentIndex so child widgets can navigate
  int get currentIndex => _currentIndex;
  set currentIndex(int v) => setState(() => _currentIndex = v);

  final List<Widget> _screens = [
    const HomeScreen(),
    const RoutesScreen(),
    const SOSScreen(),
    const AlertsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sosAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    // Sync native SOS state on first load — catches any session that started
    // before this widget was mounted (e.g. cold-start after a voice trigger).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SOSProvider>().syncWithNative();
        context.read<VoiceProvider>().initialize();
      }
    });
  }

  /// Called by the Android/iOS OS whenever the app lifecycle state changes.
  /// On [AppLifecycleState.resumed], we poll the native SOS state machine
  /// as a safety net for voice-triggered sessions that ran while the Flutter
  /// UI was backgrounded or the screen was off.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<SOSProvider>().syncWithNative();
      context.read<LocationPermissionProvider>().refreshStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sosAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();
    final safety = context.watch<SafetyProvider>();
    
    // Check for critical alerts to show pop-up
    _checkPendingSOS(safety, theme);

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(theme, lang, safety),
    );
  }

  void _checkPendingSOS(SafetyProvider safety, ThemeProvider theme) {
    if (safety.pendingSOSAlert != null) {
      final alert = safety.pendingSOSAlert!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSOSDialog(alert, safety, theme);
      });
    }
  }

  void _showSOSDialog(AlertItem alert, SafetyProvider safety, ThemeProvider theme) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFC62828), size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'SENTINEL ALERT',
                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert.title,
              style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              alert.body,
              style: TextStyle(color: theme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFFC62828), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Victim is within 5km of you. Your help could save a life.',
                      style: TextStyle(color: theme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              safety.clearPendingSOS();
              Navigator.pop(context);
            },
            child: Text('IGNORE', style: TextStyle(color: theme.textSecondary, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              safety.clearPendingSOS();
              Navigator.pop(context);
              if (alert.latitude != null && alert.longitude != null) {
                final url = Uri.parse('google.navigation:q=${alert.latitude},${alert.longitude}');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                } else {
                  final webUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${alert.latitude},${alert.longitude}');
                  await launchUrl(webUrl, mode: LaunchMode.externalApplication);
                }
              }
            },
            icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 18),
            label: const Text('NAVIGATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    ).then((_) => safety.clearPendingSOS());
  }

  Widget _buildBottomNav(ThemeProvider theme, LanguageProvider lang, SafetyProvider safety) {
    final items = [
      _NavItem(icon: Icons.home_rounded, label: lang.t('home'), index: 0),
      _NavItem(icon: Icons.map_rounded, label: lang.t('routes'), index: 1),
      _NavItem(icon: Icons.shield_rounded, label: lang.t('sos'), index: 2, isSOS: true),
      _NavItem(icon: Icons.notifications_rounded, label: lang.t('alerts'), index: 3),
      _NavItem(icon: Icons.person_rounded, label: lang.t('profile'), index: 4),
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.background.withOpacity(0.95),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: theme.border.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: theme.isDarkMode ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) => _buildTabButton(item, theme, safety)).toList(),
        ),
      ),
    );
  }

  Widget _buildTabButton(_NavItem item, ThemeProvider theme, SafetyProvider safety) {
    final isSelected = _currentIndex == item.index;

    if (item.isSOS) {
      return GestureDetector(
        onTap: () {
          if (safety.isSOSActive) {
            setState(() => _currentIndex = item.index);
          } else {
            safety.triggerSOSFlow();
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Transform.translate(
            offset: const Offset(0, -12),
            child: AnimatedBuilder(
              animation: _sosAnimController,
              builder: (ctx, child) {
                return Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: safety.isSOSActive
                          ? [const Color(0xFF1B5E20), const Color(0xFF43A047)]
                          : [const Color(0xFF8B0000), const Color(0xFFD32F2F), const Color(0xFFFF3B30)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (safety.isSOSActive ? const Color(0xFF43A047) : const Color(0xFFFF3B30)).withOpacity(0.4),
                        blurRadius: safety.isSOSActive ? 12 : 15 + (_sosAnimController.value * 10),
                        spreadRadius: safety.isSOSActive ? 2 : 1 + (_sosAnimController.value * 5),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(-2, -2),
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Icon(
                safety.isSOSActive ? Icons.shield_rounded : Icons.navigation_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
            Text(
              item.label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: safety.isSOSActive ? const Color(0xFF43A047) : theme.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = item.index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? theme.accent : theme.surface,
              boxShadow: isSelected
                  ? [BoxShadow(color: theme.accent.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 2))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: Icon(
              item.icon,
              color: isSelected ? Colors.white : theme.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: isSelected ? theme.accent : theme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int index;
  final bool isSOS;
  const _NavItem({required this.icon, required this.label, required this.index, this.isSOS = false});
}
