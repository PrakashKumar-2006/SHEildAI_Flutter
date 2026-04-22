import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

enum StatusType { safe, emergency, warning, info }

class StatusIndicator extends StatelessWidget {
  final StatusType status;
  final String message;
  final IconData? icon;
  final VoidCallback? onTap;

  const StatusIndicator({
    super.key,
    required this.status,
    required this.message,
    this.icon,
    this.onTap,
  });

  Color get _backgroundColor {
    switch (status) {
      case StatusType.safe:
        return AppColors.successContainer;
      case StatusType.emergency:
        return AppColors.errorContainer;
      case StatusType.warning:
        return AppColors.warningContainer;
      case StatusType.info:
        return AppColors.grey100;
    }
  }

  Color get _textColor {
    switch (status) {
      case StatusType.safe:
        return AppColors.success;
      case StatusType.emergency:
        return AppColors.error;
      case StatusType.warning:
        return AppColors.warning;
      case StatusType.info:
        return AppColors.textSecondary;
    }
  }

  IconData get _defaultIcon {
    switch (status) {
      case StatusType.safe:
        return Icons.check_circle;
      case StatusType.emergency:
        return Icons.warning;
      case StatusType.warning:
        return Icons.error;
      case StatusType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingL,
          vertical: AppTheme.spacingM,
        ),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: _textColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? _defaultIcon,
              color: _textColor,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              message,
              style: TextStyle(
                color: _textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
