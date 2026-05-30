import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/shake_sos_provider.dart';
import '../widgets/sos_countdown_dialog.dart';
import '../../../../providers/providers.dart';
import 'package:provider/provider.dart';

class ShakeListenerManager {
  static StreamSubscription? _subscription;

  static void initialize(BuildContext context) {
    _subscription?.cancel();
    
    final shakeProvider = Provider.of<ShakeSosProvider>(context, listen: false);
    final safetyProvider = Provider.of<SafetyProvider>(context, listen: false);

    _subscription = shakeProvider.onShakeDetected.listen((_) {
      if (context.mounted) {
        _handleShakeTrigger(context, safetyProvider);
      }
    });
  }

  static void _handleShakeTrigger(BuildContext context, SafetyProvider safetyProvider) {
    // Check if SOS is already active to avoid duplicate dialogs
    if (safetyProvider.isSOSActive) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SosCountdownDialog(
        onConfirm: () {
          safetyProvider.triggerSOSFlow();
        },
      ),
    );
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
