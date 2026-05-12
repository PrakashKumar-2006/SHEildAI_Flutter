import 'package:flutter/material.dart';
import '../../../../providers/providers.dart';
import '../../data/models/feed_models.dart';

class SafetyTipCard extends StatelessWidget {
  final SafetyTip tip;
  final ThemeProvider theme;

  const SafetyTipCard({
    super.key,
    required this.tip,
    required this.theme,
  });

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'location_on_rounded':
        return Icons.location_on_rounded;
      case 'headphones_rounded':
        return Icons.headphones_rounded;
      case 'group_rounded':
        return Icons.group_rounded;
      case 'contact_phone_rounded':
        return Icons.contact_phone_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: theme.surface,
            title: Row(
              children: [
                Icon(_getIconData(tip.icon), color: theme.accent),
                const SizedBox(width: 8),
                Expanded(child: Text(tip.title, style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold))),
              ],
            ),
            content: Text(
              tip.description + "\n\nRemember: Safety is a daily practice. Stay vigilant and share this tip with your loved ones.",
              style: TextStyle(color: theme.textPrimary, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Got it', style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
      child: Container(
      width: 260,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: theme.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIconData(tip.icon),
              color: theme.accent,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tip.title,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              tip.description,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
    );
  }
}
