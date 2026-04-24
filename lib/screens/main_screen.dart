import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';
import 'home_screen.dart';
import 'routes_screen.dart';
import 'sos_screen.dart';
import 'alerts_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _sosAnimController;

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
    _sosAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sosAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();
    final safety = context.watch<SafetyProvider>();

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(theme, lang, safety),
    );
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
          setState(() => _currentIndex = item.index);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Transform.translate(
            offset: const Offset(0, -12),
            child: AnimatedBuilder(
              animation: _sosAnimController,
              builder: (ctx, child) {
                return Transform.scale(
                  scale: safety.isSOSActive
                      ? 1.0 + (_sosAnimController.value * 0.15)
                      : 1.0,
                  child: child,
                );
              },
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: safety.isSOSActive
                        ? [const Color(0xFF1B5E20), const Color(0xFF43A047)]
                        : [const Color(0xFFCC0000), const Color(0xFFFF4D4D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (safety.isSOSActive ? const Color(0xFF43A047) : const Color(0xFFFF0000)).withOpacity(0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  safety.isSOSActive ? Icons.shield_rounded : Icons.shield_outlined,
                  color: Colors.white,
                  size: 32,
                ),
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
