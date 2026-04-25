import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../core/app_theme.dart';

class NotificationBellPopup extends StatefulWidget {
  final Color? iconColor;
  
  const NotificationBellPopup({super.key, this.iconColor});

  @override
  State<NotificationBellPopup> createState() => _NotificationBellPopupState();
}

class _NotificationBellPopupState extends State<NotificationBellPopup> {
  bool _modalVisible = false;

  void _handleOpen() {
    setState(() => _modalVisible = true);
  }

  void _handleClose() {
    setState(() => _modalVisible = false);
  }

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final safety = context.watch<SafetyProvider>();
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final alerts = safety.alerts;
    final unreadCount = alerts.length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: _handleOpen,
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Icon(
              Icons.notifications_rounded,
              size: 26,
              color: widget.iconColor ?? theme.textPrimary,
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF0000),
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        
        // Modal logic
        if (_modalVisible)
          _buildModal(context, theme, isDark, alerts),
      ],
    );
  }

  Widget _buildModal(BuildContext context, ThemeProvider theme, bool isDark, List<AlertItem> alerts) {
    // Return a dialog-like overlay since we can't easily inline a full modal in a top-appbar stack.
    // Wait, the correct way in Flutter is to show a dialog or overlay.
    // Let's use showDialog immediately and reset _modalVisible, or use a proper Overlay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_modalVisible) {
        setState(() => _modalVisible = false);
        _showPopupDialog(context, theme, isDark, alerts);
      }
    });
    return const SizedBox.shrink();
  }

  void _showPopupDialog(BuildContext context, ThemeProvider theme, bool isDark, List<AlertItem> alerts) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(ctx).size.height * 0.75,
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: theme.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                      GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Icon(Icons.close_rounded, color: theme.textPrimary),
                      ),
                    ],
                  ),
                ),
                
                // List
                Expanded(
                  child: alerts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey),
                              const SizedBox(height: 10),
                              Text('No new notifications', style: TextStyle(color: theme.textSecondary)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: alerts.length,
                          separatorBuilder: (c, i) => Divider(height: 1, color: theme.border),
                          itemBuilder: (c, i) {
                            final alert = alerts[i];
                            final isSOS = alert.type == 'SOS';
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Avatar
                                  SizedBox(
                                    width: 48, height: 48,
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: 48, height: 48,
                                          decoration: BoxDecoration(
                                            color: isSOS ? const Color(0xFFFFEBEE) : (isDark ? const Color(0xFF1e3a8a) : const Color(0xFF0D1B6E)),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isSOS ? Icons.campaign_rounded : Icons.shield_rounded,
                                            color: isSOS ? const Color(0xFFC62828) : Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 0, right: 0,
                                          child: Container(
                                            width: 18, height: 18,
                                            decoration: BoxDecoration(
                                              color: theme.surface,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: theme.surface, width: 1.5),
                                            ),
                                            child: Icon(
                                              isSOS ? Icons.error_rounded : Icons.warning_rounded,
                                              color: isSOS ? Colors.red : Colors.orange,
                                              size: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                          text: TextSpan(
                                            style: TextStyle(color: theme.textPrimary, fontSize: 14, height: 1.4),
                                            children: [
                                              TextSpan(text: isSOS ? 'SOS System ' : 'Safety Engine ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              TextSpan(text: isSOS ? 'reported an ' : 'detected a '),
                                              TextSpan(text: '${alert.title} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              TextSpan(text: alert.body),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Time
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(_getTimeAgo(alert.timestamp), style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                                      const SizedBox(height: 8),
                                      Icon(Icons.more_vert_rounded, size: 16, color: theme.textSecondary),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
