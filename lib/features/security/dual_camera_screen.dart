import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'dual_camera_controller.dart';
import 'dual_camera_view.dart';

/// DualCameraScreen — test UI for the dual-camera recording feature.
///
/// Displays the composed preview (front on top, rear on bottom) and
/// provides start / stop recording controls.
///
/// ## Integration
/// Add this screen to your router:
/// ```dart
/// GoRoute(
///   path: '/dual-camera',
///   builder: (_, __) => const DualCameraScreen(),
/// ),
/// ```
class DualCameraScreen extends StatefulWidget {
  const DualCameraScreen({super.key});

  @override
  State<DualCameraScreen> createState() => _DualCameraScreenState();
}

class _DualCameraScreenState extends State<DualCameraScreen>
    with WidgetsBindingObserver {

  // ── Controller ─────────────────────────────────────────────────────────────

  DualCameraController? _controller;
  StreamSubscription<DualCameraStatus>? _statusSub;

  // ── UI State ───────────────────────────────────────────────────────────────

  DualCameraStatus _status = DualCameraStatus.idle;
  bool _isSupported        = false;
  bool _isSupportChecked   = false;
  String? _savedPath;
  String? _errorMessage;

  // ─── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Register for app lifecycle events so we can pause/resume the camera
    // when the user backgrounds and foregrounds the app.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// Called by Flutter when the app's lifecycle state changes.
  ///
  /// [AppLifecycleState.paused]   → app went to background: pause cameras.
  /// [AppLifecycleState.resumed]  → app returned to foreground: resume cameras.
  /// [AppLifecycleState.detached] → Flutter engine about to be torn down: release.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Pause the camera streams. On the native side this:
        //   1. Stops any active recording to prevent a corrupt file.
        //   2. Steps the CameraX lifecycle down to STARTED, releasing the sensor.
        _controller?.pausePreview();
        break;
      case AppLifecycleState.resumed:
        // Re-open the camera sensors. Recording must be restarted explicitly.
        _controller?.resumePreview();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Release everything — the view is about to be destroyed anyway.
        _controller?.dispose();
        break;
    }
  }

  // ─── Native view ready ──────────────────────────────────────────────────────

  /// Called once by [DualCameraView] when the native AndroidView is ready.
  Future<void> _onViewCreated(DualCameraController controller) async {
    _controller = controller;

    // Wire status stream to setState
    _statusSub = controller.statusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _status = status;
        if (status == DualCameraStatus.stopped) {
          _savedPath = controller.outputPath;
        }
        if (status == DualCameraStatus.error) {
          _errorMessage = controller.lastError;
        }
      });
    });

    // Check hardware support immediately after view is ready
    final supported = await controller.checkSupport();
    if (!mounted) return;

    setState(() {
      _isSupported      = supported;
      _isSupportChecked = true;
      if (!supported) {
        _status = DualCameraStatus.unsupported;
      }
    });
  }

  // ─── Recording controls ─────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_controller == null || !_isSupported) return;
    setState(() { _savedPath = null; _errorMessage = null; });
    await _controller!.startRecording();
  }

  Future<void> _stopRecording() async {
    await _controller?.stopRecording();
  }

  // ─── UI helpers ─────────────────────────────────────────────────────────────

  String get _statusLabel {
    switch (_status) {
      case DualCameraStatus.idle:          return 'Ready';
      case DualCameraStatus.initialising:  return 'Starting cameras…';
      case DualCameraStatus.recording:     return '● REC';
      case DualCameraStatus.stopped:       return 'Saved';
      case DualCameraStatus.unsupported:   return 'Not Supported';
      case DualCameraStatus.error:         return 'Error';
    }
  }

  Color get _statusColor {
    switch (_status) {
      case DualCameraStatus.recording:    return const Color(0xFFF87171); // red
      case DualCameraStatus.stopped:      return const Color(0xFF34D399); // green
      case DualCameraStatus.unsupported:  return const Color(0xFFFBBF24); // amber
      case DualCameraStatus.error:        return const Color(0xFFF87171); // red
      case DualCameraStatus.initialising: return const Color(0xFF60A5FA); // blue
      case DualCameraStatus.idle:         return const Color(0xFF94A3B8); // grey
    }
  }

  bool get _canStart =>
      _isSupported &&
      _status != DualCameraStatus.recording &&
      _status != DualCameraStatus.initialising;

  bool get _canStop =>
      _status == DualCameraStatus.recording ||
      _status == DualCameraStatus.initialising;

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Dual Camera',
          style: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
      ),
      body: Column(
        children: [

          // ── Camera preview ─────────────────────────────────────────────────
          Expanded(
            flex: 7,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft:  Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: Stack(
                children: [
                  // Native split-screen preview
                  DualCameraView(onViewCreated: _onViewCreated),

                  // Camera label overlays
                  _buildCameraLabel('FRONT', Alignment.topCenter),
                  _buildCameraLabel('REAR',  Alignment.bottomCenter),

                  // Centre divider line
                  const Align(
                    alignment: Alignment.center,
                    child: _DividerLine(),
                  ),

                  // Loading overlay — shown until checkSupport() returns
                  if (!_isSupportChecked)
                    const _LoadingOverlay(),

                  // Unsupported device overlay — shown when hardware cannot
                  // run concurrent cameras. Replaces the preview content.
                  if (_isSupportChecked && !_isSupported)
                    const _UnsupportedOverlay(),
                ],
              ),
            ),
          ),

          // ── Control panel ──────────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [

                  // Status badge
                  _StatusBadge(label: _statusLabel, color: _statusColor),

                  // Saved path
                  if (_savedPath != null)
                    _InfoChip(
                      icon: Icons.check_circle_outline,
                      text: 'Saved: …/${_savedPath!.split('/').last}',
                      color: const Color(0xFF34D399),
                    ),

                  // Error message
                  if (_errorMessage != null)
                    _InfoChip(
                      icon: Icons.error_outline,
                      text: _errorMessage!,
                      color: const Color(0xFFF87171),
                    ),

                  // Record / Stop buttons
                  Row(
                    children: [
                      Expanded(
                        child: _RecordButton(
                          label: 'Record',
                          icon: Icons.fiber_manual_record,
                          color: const Color(0xFFEF4444),
                          enabled: _canStart,
                          onPressed: _startRecording,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _RecordButton(
                          label: 'Stop',
                          icon: Icons.stop,
                          color: const Color(0xFF64748B),
                          enabled: _canStop,
                          onPressed: _stopRecording,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Camera label helper ─────────────────────────────────────────────────────

  Widget _buildCameraLabel(String label, Alignment alignment) {
    final isTop = alignment == Alignment.topCenter;
    return Align(
      alignment: alignment,
      child: Padding(
        padding: EdgeInsets.only(
          top:    isTop  ? 12 : 0,
          bottom: !isTop ? 12 : 0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 1.5,
      color: Colors.white.withValues(alpha: 0.25),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkBackground.withValues(alpha: 0.85),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.darkAccent),
            SizedBox(height: 16),
            Text(
              'Checking camera support…',
              style: TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen overlay shown when the device hardware does not support
/// simultaneous front + back camera streaming.
///
/// Displayed on top of the native [AndroidView] so the user never sees a
/// broken preview — they see a clear, actionable explanation instead.
class _UnsupportedOverlay extends StatelessWidget {
  const _UnsupportedOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.darkBackground.withValues(alpha: 0.97),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon with amber glow
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.12),
                  border: Border.all(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.videocam_off_rounded,
                  color: Color(0xFFFBBF24),
                  size: 40,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Dual Camera Not Supported',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.darkTextPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Your device\'s camera hardware does not support '
                'opening the front and rear cameras simultaneously.\n\n'
                'This feature requires a device with a multi-stream '
                'Image Signal Processor (ISP).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.darkTextSecondary,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String   text;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
  });

  final String   label;
  final IconData icon;
  final Color    color;
  final bool     enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1.0 : 0.35,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor:         color,
          disabledBackgroundColor: color,
          foregroundColor:         Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: enabled ? 4 : 0,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize:   15,
          ),
        ),
      ),
    );
  }
}
