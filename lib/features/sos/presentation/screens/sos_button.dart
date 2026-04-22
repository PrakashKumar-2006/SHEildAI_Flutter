import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class SOSButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isActive;
  final double size;

  const SOSButton({
    super.key,
    required this.onPressed,
    this.isActive = false,
    this.size = 200,
  });

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: widget.isActive
                    ? [AppColors.sosActive, AppColors.primaryDark]
                    : [AppColors.primary, AppColors.primaryLight],
              ),
              boxShadow: widget.isActive
                  ? [
                      BoxShadow(
                        color: AppColors.sosActive.withValues(alpha: 0.5),
                        blurRadius: 30 * _pulseAnimation.value,
                        spreadRadius: 10 * _pulseAnimation.value,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isActive ? Icons.stop : Icons.emergency,
                    size: widget.size * 0.35,
                    color: AppColors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isActive ? 'CANCEL' : 'SOS',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: widget.size * 0.15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
