import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

// ─── Channel name constants ───────────────────────────────────────────────────
// Must exactly match DualCameraConstants.kt on the native side.

abstract final class _DualCameraChannels {
  static const methodChannelBase = 'com.nexus.sheildai/dual_camera';
  static const eventChannelBase  = 'com.nexus.sheildai/dual_camera_events';
}

// ─── Status constants ─────────────────────────────────────────────────────────
// Matches the STATUS_* constants in DualCameraConstants.kt.

/// Represents the current state of the dual-camera recording session.
enum DualCameraStatus {
  /// Initial / idle — no session active.
  idle,

  /// Cameras are opening and the compositor pipeline is setting up.
  initialising,

  /// Active dual-camera recording is in progress.
  recording,

  /// Recording stopped and the output file has been finalised.
  stopped,

  /// Device hardware does not support concurrent front+back camera access.
  unsupported,

  /// An error occurred — check [DualCameraController.lastError].
  error;

  /// Parses the raw status string pushed from native.
  static DualCameraStatus fromNative(String? raw) {
    switch (raw) {
      case 'initialising': return initialising;
      case 'recording':    return recording;
      case 'stopped':      return stopped;
      case 'unsupported':  return unsupported;
      default:
        debugPrint('[DualCameraController] Unknown status: "$raw"');
        return idle;
    }
  }

  bool get isActive => this == recording || this == initialising;
}

// ─── Event model ──────────────────────────────────────────────────────────────

/// A decoded event from the native dual-camera EventChannel.
class DualCameraEvent {
  /// 'status' or 'error' — matches EVENT_TYPE_* constants in DualCameraConstants.kt.
  final String type;

  /// For status events: a DualCameraStatus string.
  /// For error events: the error message string.
  final String payload;

  const DualCameraEvent({required this.type, required this.payload});

  bool get isError  => type == 'error';
  bool get isStatus => type == 'status';

  @override
  String toString() => 'DualCameraEvent(type: $type, payload: $payload)';
}

// ─── Controller ──────────────────────────────────────────────────────────────

/// DualCameraController — Flutter-side bridge to the native dual-camera recording engine.
///
/// This is the **only** Dart file that directly touches the native
/// [MethodChannel] and [EventChannel] for dual-camera recording.
/// All UI code should use this controller or listen to [statusStream].
///
/// ## Lifecycle
///
/// ```dart
/// // 1. Create the controller with the viewId provided by AndroidView.onPlatformViewCreated
/// final controller = DualCameraController(viewId: id);
///
/// // 2. Check hardware support before attempting to record
/// final supported = await controller.checkSupport();
///
/// // 3. Listen to status stream
/// controller.statusStream.listen((status) { ... });
///
/// // 4. Start recording — outputPath is auto-generated if not provided
/// await controller.startRecording();
///
/// // 5. Stop when done
/// await controller.stopRecording();
///
/// // 6. Always dispose when the widget is removed
/// controller.dispose();
/// ```
///
/// ## Channel Namespacing
/// Channels are namespaced by [viewId] (e.g. `com.nexus.sheildai/dual_camera/0`)
/// to match the native [DualCameraView] which does the same. This allows
/// multiple [DualCameraView] widgets to coexist without interference.
class DualCameraController {
  DualCameraController({required this.viewId}) {
    _methodChannel = MethodChannel(
      '${_DualCameraChannels.methodChannelBase}/$viewId',
    );
    _eventChannel = EventChannel(
      '${_DualCameraChannels.eventChannelBase}/$viewId',
    );
    _subscribeToEvents();
  }

  /// The viewId assigned by Flutter when the [AndroidView] platform view is created.
  final int viewId;

  late final MethodChannel _methodChannel;
  late final EventChannel  _eventChannel;

  // ── Public state ──────────────────────────────────────────────────────────

  DualCameraStatus _status = DualCameraStatus.idle;
  String? _lastError;
  String? _outputPath;

  /// Current recording status.
  DualCameraStatus get status => _status;

  /// The last error message received from native, if any.
  String? get lastError => _lastError;

  /// Absolute path of the output video file after recording completes.
  String? get outputPath => _outputPath;

  bool get isRecording => _status.isActive;

  // ── Status stream ─────────────────────────────────────────────────────────

  final _statusController = StreamController<DualCameraStatus>.broadcast();

  /// Broadcast stream that emits every time the recording status changes.
  /// Backed by the native EventChannel — no polling required.
  Stream<DualCameraStatus> get statusStream => _statusController.stream;

  // ── Raw event stream (for advanced use) ──────────────────────────────────

  final _eventController = StreamController<DualCameraEvent>.broadcast();

  /// Broadcast stream of raw [DualCameraEvent] objects (status + error events).
  Stream<DualCameraEvent> get eventStream => _eventController.stream;

  // ─── EventChannel subscription ────────────────────────────────────────────

  StreamSubscription<Object?>? _nativeSub;

  void _subscribeToEvents() {
    _nativeSub = _eventChannel.receiveBroadcastStream().listen(
      (raw) {
        try {
          final map     = Map<String, dynamic>.from(raw as Map);
          final type    = map['type']    as String? ?? 'status';
          final payload = map['payload'] as String? ?? '';

          final event = DualCameraEvent(type: type, payload: payload);
          debugPrint('[DualCameraController#$viewId] ← $event');

          _eventController.add(event);

          if (event.isStatus) {
            final newStatus = DualCameraStatus.fromNative(payload);
            _status = newStatus;
            _statusController.add(newStatus);
          } else if (event.isError) {
            _lastError = payload;
            _status    = DualCameraStatus.error;
            _statusController.add(DualCameraStatus.error);
          }
        } catch (e) {
          debugPrint('[DualCameraController#$viewId] Event decode error: $e (raw: $raw)');
        }
      },
      onError: (Object err) {
        debugPrint('[DualCameraController#$viewId] EventChannel error: $err');
        _lastError = err.toString();
        _status    = DualCameraStatus.error;
        _statusController.add(DualCameraStatus.error);
      },
    );
  }

  // ─── MethodChannel API ────────────────────────────────────────────────────

  /// Returns [true] if the device hardware supports simultaneous front + back
  /// camera streaming, [false] otherwise.
  ///
  /// **Call this before [startRecording].** On unsupported devices, starting
  /// the recording will fail silently; checking first lets you show a proper
  /// fallback UI.
  ///
  /// Never throws — returns [false] on any error.
  Future<bool> checkSupport() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('checkSupport');
      final supported = result ?? false;
      debugPrint('[DualCameraController#$viewId] checkSupport → $supported');
      return supported;
    } on PlatformException catch (e) {
      debugPrint('[DualCameraController#$viewId] checkSupport PlatformException: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[DualCameraController#$viewId] checkSupport error: $e');
      return false;
    }
  }

  /// Starts dual-camera recording and saves to [outputPath].
  ///
  /// If [outputPath] is null, an auto-generated path in the app's external
  /// movies directory is used:
  ///   `<externalFilesDir>/Movies/SHEildAI/dual_<timestamp>.mp4`
  ///
  /// Returns the resolved output path, or null if an error occurred.
  Future<String?> startRecording({String? outputPath}) async {
    try {
      final resolvedPath = outputPath ?? await _buildOutputPath();
      _outputPath = resolvedPath;

      debugPrint('[DualCameraController#$viewId] startRecording → $resolvedPath');

      await _methodChannel.invokeMethod<void>(
        'startRecording',
        {'outputPath': resolvedPath},
      );
      return resolvedPath;
    } on PlatformException catch (e) {
      debugPrint('[DualCameraController#$viewId] startRecording PlatformException: ${e.message}');
      _lastError = e.message;
      _status    = DualCameraStatus.error;
      _statusController.add(DualCameraStatus.error);
      return null;
    } catch (e) {
      debugPrint('[DualCameraController#$viewId] startRecording error: $e');
      _lastError = e.toString();
      _status    = DualCameraStatus.error;
      _statusController.add(DualCameraStatus.error);
      return null;
    }
  }

  /// Stops the active dual-camera recording and finalises the output file.
  ///
  /// After calling this, listen to [statusStream] for [DualCameraStatus.stopped]
  /// which confirms the file has been written to [outputPath].
  ///
  /// Safe to call even if not currently recording.
  Future<void> stopRecording() async {
    try {
      debugPrint('[DualCameraController#$viewId] stopRecording');
      await _methodChannel.invokeMethod<void>('stopRecording');
    } on PlatformException catch (e) {
      debugPrint('[DualCameraController#$viewId] stopRecording PlatformException: ${e.message}');
    } catch (e) {
      debugPrint('[DualCameraController#$viewId] stopRecording error: $e');
    }
  }

  /// Pauses the camera preview streams.
  ///
  /// Call this when the app goes to the background
  /// (e.g. from a [WidgetsBindingObserver.didChangeAppLifecycleState] callback).
  ///
  /// Any active recording is stopped automatically on the native side before
  /// the sensors are released, preventing a corrupt output file.
  Future<void> pausePreview() async {
    try {
      debugPrint('[DualCameraController#$viewId] pausePreview');
      await _methodChannel.invokeMethod<void>('pausePreview');
    } on PlatformException catch (e) {
      debugPrint('[DualCameraController#$viewId] pausePreview PlatformException: ${e.message}');
    } catch (e) {
      debugPrint('[DualCameraController#$viewId] pausePreview error: $e');
    }
  }

  /// Resumes the camera preview streams after a [pausePreview] call.
  ///
  /// Call this when the app returns to the foreground.
  /// This does **not** restart a recording — call [startRecording] explicitly
  /// if you want to resume recording after foregrounding.
  Future<void> resumePreview() async {
    try {
      debugPrint('[DualCameraController#$viewId] resumePreview');
      await _methodChannel.invokeMethod<void>('resumePreview');
    } on PlatformException catch (e) {
      debugPrint('[DualCameraController#$viewId] resumePreview PlatformException: ${e.message}');
    } catch (e) {
      debugPrint('[DualCameraController#$viewId] resumePreview error: $e');
    }
  }

  // ─── Dispose ──────────────────────────────────────────────────────────────

  /// Releases all resources. Must be called when the owning widget is disposed.
  void dispose() {
    debugPrint('[DualCameraController#$viewId] dispose()');
    _nativeSub?.cancel();
    _statusController.close();
    _eventController.close();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Builds a timestamped output path inside the app's external files directory.
  /// Falls back to the app's temp directory if external storage is unavailable.
  static Future<String> _buildOutputPath() async {
    Directory? dir;
    try {
      // getExternalStorageDirectory → e.g. /sdcard/Android/data/com.shieldai.app/files
      dir = await getExternalStorageDirectory();
    } catch (_) {
      dir = null;
    }
    dir ??= await getTemporaryDirectory();

    final moviesDir = Directory('${dir.path}/Movies/SHEildAI');
    await moviesDir.create(recursive: true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${moviesDir.path}/dual_$timestamp.mp4';
  }
}
