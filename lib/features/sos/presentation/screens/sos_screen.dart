import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sos_provider.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {

  @override
  void initState() {
    super.initState();
    // Sync local Flutter state with the native SOS state machine.
    // This is a safety net for voice-triggered SOS sessions that began
    // while the SOSScreen was not open (e.g. user was on home screen).
    // The EventChannel buffer in SOSEventChannel.kt will also replay any
    // missed events — but this poll covers the case where the subscription
    // itself was the race condition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SOSProvider>().syncWithNative();
      }
    });
  }

  Future<void> _startSOS() async {
    final provider = context.read<SOSProvider>();
    if (!provider.isNativeSOSActive) {
      await provider.triggerSOS();
    }
  }

  Future<void> _stopSOS() async {
    final provider = context.read<SOSProvider>();
    if (provider.isNativeSOSActive) {
      await provider.cancelSOS();
    }
  }

  Color _getBackgroundColor(SOSProvider provider) {
    if (provider.isInCooldown) return const Color(0xFF3B3B00); // Dark Yellow for Cooldown
    if (provider.isNativeSOSActive) return const Color(0xFF3B0000); // Dark red
    return Colors.black; // Safe / Idle
  }

  Color _getStatusColor(SOSProvider provider) {
    if (provider.isInCooldown) return Colors.yellowAccent;
    if (provider.isNativeSOSActive) return Colors.redAccent;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SOSProvider>(
      builder: (context, provider, child) {
        final status = provider.nativeState.displayName;
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('SOS', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            centerTitle: true,
          ),
          extendBodyBehindAppBar: true,
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            color: _getBackgroundColor(provider),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      color: _getStatusColor(provider),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                    child: Text('STATUS: ${status.toUpperCase()}'),
                  ),
                  const SizedBox(height: 10),
                  if (provider.isNativeSOSActive)
                    Text(
                      provider.sessionDuration,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  if (provider.isInBuffer)
                    Text(
                      '${provider.bufferSecondsRemaining ?? 3}s',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  if (provider.isInCooldown)
                    Text(
                      '${provider.cooldownSecondsRemaining ?? 60}s',
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  const SizedBox(height: 50),
                  ElevatedButton(
                    onPressed: provider.isNativeSOSActive || provider.isInCooldown ? null : _startSOS,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      disabledBackgroundColor: Colors.red.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                    child: const Text(
                      'START SOS',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: provider.isNativeSOSActive ? _stopSOS : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      disabledBackgroundColor: Colors.green.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                    child: const Text(
                      "I'M SAFE",
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
