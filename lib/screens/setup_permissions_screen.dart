import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';

class SetupPermissionsScreen extends StatefulWidget {
  const SetupPermissionsScreen({super.key});

  @override
  State<SetupPermissionsScreen> createState() => _SetupPermissionsScreenState();
}

class _SetupPermissionsScreenState extends State<SetupPermissionsScreen> {
  int _currentStep = 0; // 0 = intro, 1..4 = permissions

  final List<_PermissionStep> _steps = [
    _PermissionStep(
      id: 'intro',
      icon: Icons.shield_rounded,
      iconColor: Color(0xFF1976D2),
      title: 'Your Security Setup',
      titleKey: 'your_security_setup',
      descKey: 'security_setup_desc',
      fallbackKey: '',
    ),
    _PermissionStep(
      id: 'location',
      icon: Icons.location_on_rounded,
      iconColor: Color(0xFF4CAF50),
      title: 'Always-On Location',
      titleKey: 'always_on_location',
      descKey: 'location_desc',
      fallbackKey: 'location_fallback',
    ),
    _PermissionStep(
      id: 'av',
      icon: Icons.videocam_rounded,
      iconColor: Color(0xFFFF9800),
      title: 'Camera & Microphone',
      titleKey: 'camera_microphone',
      descKey: 'av_desc',
      fallbackKey: 'av_fallback',
    ),
    _PermissionStep(
      id: 'notifications',
      icon: Icons.notifications_rounded,
      iconColor: Color(0xFF9C27B0),
      title: 'Immediate Alerts',
      titleKey: 'immediate_alerts',
      descKey: 'notif_desc',
      fallbackKey: 'notif_fallback',
    ),
    _PermissionStep(
      id: 'sms',
      icon: Icons.chat_bubble_rounded,
      iconColor: Color(0xFFF44336),
      title: 'Emergency SMS',
      titleKey: 'emergency_sms',
      descKey: 'sms_desc',
      fallbackKey: 'sms_fallback',
    ),
  ];

  Future<void> _handleNext({bool skip = false}) async {
    // In actual implementation, we would request permissions here if !skip
    
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _finalizeSetup();
    }
  }

  Future<void> _finalizeSetup() async {
    final safety = context.read<SafetyProvider>();
    final updated = safety.userProfile.copyWith(isSetupComplete: true);
    await safety.updateUserProfile(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LanguageProvider>();

    final stepItem = _steps[_currentStep];
    final totalActionableSteps = _steps.length - 1; // 4
    final currentActionableStep = _currentStep > 0 ? _currentStep : 0;
    final percentage = (currentActionableStep / totalActionableSteps * 100).round();

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Header Info
                    if (_currentStep > 0) ...[
                      const SizedBox(height: 20),
                      Text(
                        'STEP $_currentStep OF $totalActionableSteps',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _currentStep == totalActionableSteps
                              ? "You're almost fully protected!"
                              : "You're $percentage% protected",
                          style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ] else ...[
                      const SizedBox(height: 60),
                    ],

                    // Content
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            stepItem.iconColor.withOpacity(0.4),
                            stepItem.iconColor.withOpacity(0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Center(
                        child: Icon(stepItem.icon, size: 60, color: stepItem.iconColor),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Text(
                      lang.t(stepItem.titleKey).isNotEmpty ? lang.t(stepItem.titleKey) : stepItem.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textPrimary, fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      lang.t(stepItem.descKey).isNotEmpty ? lang.t(stepItem.descKey) : stepItem.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textPrimary, fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 20),

                    if (stepItem.fallbackKey.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.info_outline_rounded, color: Color(0xFF757575), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                lang.t(stepItem.fallbackKey),
                                style: TextStyle(color: theme.textSecondary, fontSize: 13, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _handleNext(skip: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: Colors.black.withOpacity(0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep == 0
                                ? 'Start Setup'
                                : _currentStep == _steps.length - 1
                                    ? 'Grant & Finish'
                                    : 'Grant & Continue',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentStep == 0 ? Icons.arrow_forward_rounded : Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _handleNext(skip: true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Skip (App will not be fully active)',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionStep {
  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String titleKey;
  final String descKey;
  final String fallbackKey;

  const _PermissionStep({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleKey,
    required this.descKey,
    required this.fallbackKey,
  });
}
