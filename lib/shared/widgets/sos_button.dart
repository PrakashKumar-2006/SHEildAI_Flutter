import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class SOSButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isActive;
  final double size;
  final String? activeText;
  final String? inactiveText;
  final Duration holdDuration;

  const SOSButton({
    super.key,
    required this.onPressed,
    this.isActive = false,
    this.size = 200,
    this.activeText,
    this.inactiveText,
    this.holdDuration = const Duration(seconds: 2),
  });

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  bool _isHolding = false;
  double _holdProgress = 0.0;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isActive) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SOSButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  void _startHold() {
    if (widget.isActive) return;
    
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    _animationController.forward();

    const updateInterval = Duration(milliseconds: 50);
    final totalSteps = widget.holdDuration.inMilliseconds ~/ updateInterval.inMilliseconds;
    var currentStep = 0;

    _holdTimer = Timer.periodic(updateInterval, (timer) {
      if (currentStep >= totalSteps) {
        timer.cancel();
        _triggerSOS();
      } else {
        setState(() {
          _holdProgress = currentStep / totalSteps;
        });
        currentStep++;
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
    _animationController.reverse();
  }

  void _triggerSOS() {
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
    widget.onPressed();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startHold(),
      onLongPressEnd: (_) => _cancelHold(),
      onLongPressCancel: () => _cancelHold(),
      onTap: widget.isActive ? widget.onPressed : null,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final scale = widget.isActive
              ? _pulseAnimation.value
              : (_isHolding ? _scaleAnimation.value : 1.0);

          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: widget.isActive
                      ? [AppColors.primaryLight, AppColors.primaryDark]
                      : [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: widget.isActive
                    ? [
                        BoxShadow(
                          color: AppColors.sosActive.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 15,
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
              child: Stack(
                children: [
                  // Progress indicator for hold-to-trigger
                  if (_isHolding)
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        value: _holdProgress,
                        strokeWidth: 8,
                        backgroundColor: AppColors.white.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                      ),
                    ),
                  // Center content
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.isActive ? Icons.stop : Icons.emergency,
                          size: widget.size * 0.35,
                          color: AppColors.white,
                        ),
                        const SizedBox(height: AppTheme.spacingS),
                        Text(
                          widget.isActive
                              ? (widget.activeText ?? 'CANCEL')
                              : (_isHolding
                                  ? 'HOLD...'
                                  : (widget.inactiveText ?? 'SOS')),
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: widget.size * 0.12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        if (_isHolding) ...[
                          const SizedBox(height: AppTheme.spacingXS),
                          Text(
                            '${((_holdProgress * 100).toInt())}%',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: widget.size * 0.08,
                              fontWeight: FontWeight.w600,
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
        },
      ),
    );
  }
}
