import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';

class PermissionItem {
  final String title;
  final String description;
  final IconData icon;
  final Permission permission;

  PermissionItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.permission,
  });
}

class SystemPermissionsScreen extends StatefulWidget {
  const SystemPermissionsScreen({super.key});

  @override
  State<SystemPermissionsScreen> createState() => _SystemPermissionsScreenState();
}

class _SystemPermissionsScreenState extends State<SystemPermissionsScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  Map<Permission, PermissionStatus> _statuses = {};

  final List<PermissionItem> _permissions = [
    PermissionItem(
      title: 'Location',
      description: 'Required for SOS tracking and safe routing.',
      icon: Icons.location_on_rounded,
      permission: Permission.locationAlways,
    ),
    PermissionItem(
      title: 'Camera',
      description: 'Captures video evidence during an active SOS.',
      icon: Icons.camera_alt_rounded,
      permission: Permission.camera,
    ),
    PermissionItem(
      title: 'Microphone',
      description: 'Listens for voice triggers and records audio evidence.',
      icon: Icons.mic_rounded,
      permission: Permission.microphone,
    ),
    PermissionItem(
      title: 'SMS & Contacts',
      description: 'Sends emergency alerts to your trusted contacts.',
      icon: Icons.sms_rounded,
      permission: Permission.sms,
    ),
    PermissionItem(
      title: 'Notifications',
      description: 'Keeps you updated on active safety features.',
      icon: Icons.notifications_active_rounded,
      permission: Permission.notification,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    
    Map<Permission, PermissionStatus> statuses = {};
    for (var item in _permissions) {
      // Special handling: if locationAlways is denied, check basic location
      if (item.permission == Permission.locationAlways) {
        var alwaysStatus = await Permission.locationAlways.status;
        var whenInUseStatus = await Permission.locationWhenInUse.status;
        
        if (alwaysStatus.isGranted) {
          statuses[item.permission] = PermissionStatus.granted;
        } else if (whenInUseStatus.isGranted) {
          // If only 'when in use' is granted, we still consider it partially granted
          // but for SOS background tracking, we usually want 'always'. 
          statuses[item.permission] = PermissionStatus.granted; // Or a custom state
        } else {
          statuses[item.permission] = alwaysStatus;
        }
      } else {
        statuses[item.permission] = await item.permission.status;
      }
    }

    if (mounted) {
      setState(() {
        _statuses = statuses;
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePermissionTap(PermissionItem item) async {
    final currentStatus = _statuses[item.permission];

    if (currentStatus != null && currentStatus.isGranted) {
      // If already granted, the only way to revoke is through App Settings
      openAppSettings();
      return;
    }

    // Attempt to request permission natively
    PermissionStatus newStatus;
    
    // For locationAlways, we must request locationWhenInUse first on Android 11+
    if (item.permission == Permission.locationAlways) {
      var inUse = await Permission.locationWhenInUse.status;
      if (!inUse.isGranted) {
        await Permission.locationWhenInUse.request();
      }
      newStatus = await Permission.locationAlways.request();
    } else {
      newStatus = await item.permission.request();
    }

    if (mounted) {
      setState(() {
        _statuses[item.permission] = newStatus;
      });
      
      // If permanently denied or restricted, open settings
      if (newStatus.isPermanentlyDenied || newStatus.isRestricted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable this permission in settings.'),
            duration: Duration(seconds: 2),
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          openAppSettings();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    // final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'System Permissions',
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.accent))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _permissions.length,
              itemBuilder: (context, index) {
                final item = _permissions[index];
                final status = _statuses[item.permission] ?? PermissionStatus.denied;
                final isGranted = status.isGranted;

                return _buildPermissionCard(theme, item, isGranted);
              },
            ),
    );
  }

  Widget _buildPermissionCard(ThemeProvider theme, PermissionItem item, bool isGranted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isGranted ? const Color(0xFF4CAF50).withOpacity(0.3) : theme.border,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handlePermissionTap(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isGranted ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    color: isGranted ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isGranted ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isGranted ? 'Allowed' : 'Denied',
                              style: TextStyle(
                                color: isGranted ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.description,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
