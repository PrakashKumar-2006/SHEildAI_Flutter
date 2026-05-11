import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dual_camera_controller.dart';

// ─── View type ID ─────────────────────────────────────────────────────────────
// Must exactly match DualCameraConstants.VIEW_TYPE_ID in Kotlin.
const _kViewTypeId = 'com.nexus.sheildai/dual_camera_view';

/// DualCameraView — Flutter widget that embeds the native Android camera preview.
///
/// Renders a full-height [AndroidView] backed by [DualCameraView.kt] on the
/// native side. Once the native view is created, the [onViewCreated] callback
/// fires with the [DualCameraController] that the parent widget can use to
/// drive recording.
///
/// ## Usage
///
/// ```dart
/// DualCameraView(
///   onViewCreated: (controller) {
///     _controller = controller;
///   },
/// )
/// ```
///
/// ## Platform
/// Android only. On other platforms this renders a [_UnsupportedPlatformView].
class DualCameraView extends StatelessWidget {
  const DualCameraView({
    super.key,
    required this.onViewCreated,
  });

  /// Called once the native view is ready.
  /// [controller] is pre-wired to the native MethodChannel and EventChannel
  /// for this specific view instance.
  final void Function(DualCameraController controller) onViewCreated;

  @override
  Widget build(BuildContext context) {
    // Only supported on Android
    if (!defaultTargetPlatform.isAndroid) {
      return const _UnsupportedPlatformView();
    }

    return AndroidView(
      viewType: _kViewTypeId,
      layoutDirection: TextDirection.ltr,
      creationParams: const <String, dynamic>{},
      creationParamsCodec: const StandardMessageCodec(),
      // Use hybrid composition for better surface lifecycle handling
      // and compatibility with CameraX's PreviewView.
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      onPlatformViewCreated: (int viewId) {
        debugPrint('[DualCameraView] Platform view created — viewId: $viewId');
        final controller = DualCameraController(viewId: viewId);
        onViewCreated(controller);
      },
    );
  }
}

// ─── Platform extension helper ────────────────────────────────────────────────

extension on TargetPlatform {
  bool get isAndroid => this == TargetPlatform.android;
}

// ─── Fallback for non-Android ─────────────────────────────────────────────────

class _UnsupportedPlatformView extends StatelessWidget {
  const _UnsupportedPlatformView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, color: Colors.white54, size: 48),
            SizedBox(height: 12),
            Text(
              'Dual camera recording is\nonly supported on Android.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
