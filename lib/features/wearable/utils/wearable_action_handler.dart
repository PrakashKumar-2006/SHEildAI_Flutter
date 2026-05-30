import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/providers.dart';
import '../../sos/presentation/providers/sos_provider.dart';

class WearableActionHandler {
  static const String actionCancelSos = 'CANCEL_SOS';
  static const String actionCallGuardian = 'CALL_GUARDIAN';
  static const String actionViewAlert = 'VIEW_ALERT';
  static const String actionOpenApp = 'OPEN_APP';

  static void handleAction(BuildContext context, String action) {
    debugPrint('[WearableActionHandler] Handling action: $action');
    
    switch (action) {
      case actionCancelSos:
        _handleCancelSos(context);
        break;
      case actionCallGuardian:
        _handleCallGuardian(context);
        break;
      case actionViewAlert:
        _handleViewAlert(context);
        break;
      case actionOpenApp:
        _handleOpenApp(context);
        break;
      default:
        debugPrint('[WearableActionHandler] Unknown action: $action');
    }
  }

  static void _handleCancelSos(BuildContext context) {
    final sosProvider = Provider.of<SOSProvider>(context, listen: false);
    sosProvider.cancelSOS();
  }

  static void _handleCallGuardian(BuildContext context) {
    final safetyProvider = Provider.of<SafetyProvider>(context, listen: false);
    // Logic to call primary guardian
    if (safetyProvider.trustedContacts.isNotEmpty) {
      // Use existing SMS/Call logic if available
      debugPrint('[WearableActionHandler] Calling primary guardian...');
    }
  }

  static void _handleViewAlert(BuildContext context) {
    // Navigate to safety feed
    Navigator.of(context).pushNamed('/safety_feed');
  }

  static void _handleOpenApp(BuildContext context) {
    // Already handled by system usually, but can be used for specific routing
    Navigator.of(context).pushNamed('/main');
  }
}
