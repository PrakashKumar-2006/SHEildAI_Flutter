import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// SOSNativeState — mirrors the Kotlin SOSState enum.
///
/// Returned from [SOSPlatformService.getState] and passed to listeners
/// so the Flutter UI can react to state changes.
enum SOSNativeState {
  idle,
  triggered,
  buffer,
  recordingAudio,
  recordingVideo,
  stopped,
  cooldown,
  unknown;

  /// Parses a raw string returned by the native channel.
  static SOSNativeState fromString(String? raw) {
    switch (raw?.toUpperCase()) {
      case 'IDLE':
        return idle;
      case 'TRIGGERED':
        return triggered;
      case 'BUFFER':
        return buffer;
      case 'RECORDING_AUDIO':
        return recordingAudio;
      case 'RECORDING_VIDEO':
        return recordingVideo;
      case 'STOPPED':
        return stopped;
      case 'COOLDOWN':
        return cooldown;
      default:
        debugPrint('[SOSPlatformService] Unknown state string: "$raw"');
        return unknown;
    }
  }

  /// True while an SOS session is in progress.
  bool get isActive => switch (this) {
        triggered || buffer || recordingAudio || recordingVideo => true,
        _ => false,
      };

  /// Human-readable label for UI display.
  String get displayName => switch (this) {
        idle => 'Ready',
        triggered => 'Triggered',
        buffer => 'Preparing…',
        recordingAudio => 'Recording Audio',
        recordingVideo => 'Recording Video',
        stopped => 'Stopped',
        cooldown => 'Cooldown',
        unknown => 'Unknown',
      };
}

// ─── Event names (must match SOSEventChannel.kt constants) ─────────────────

abstract final class SOSEventName {
  static const sosStarted       = 'SOS_STARTED';
  static const bufferStarted    = 'BUFFER_STARTED';
  static const recordingStarted = 'RECORDING_STARTED';
  static const videoStarted     = 'VIDEO_STARTED';
  static const sessionEnded     = 'SESSION_ENDED';
  static const cooldownStarted  = 'COOLDOWN_STARTED';
  static const idle             = 'IDLE';
}

/// SOSEvent — a decoded real-time event from the native [SOSEventChannel].
///
/// [type]    — one of the [SOSEventName] constants.
/// [payload] — optional metadata map (e.g. bufferMs, durationMs).
class SOSEvent {
  final String type;
  final Map<String, dynamic> payload;

  const SOSEvent({required this.type, this.payload = const {}});

  /// Convenience: extracts `bufferMs` from a BUFFER_STARTED payload.
  int get bufferMs => (payload['bufferMs'] as num?)?.toInt() ?? 3000;

  /// Convenience: extracts `cooldownMs` from a COOLDOWN_STARTED payload.
  int get cooldownMs => (payload['cooldownMs'] as num?)?.toInt() ?? 60000;

  /// Convenience: extracts `durationMs` from a SESSION_ENDED payload.
  int get durationMs => (payload['durationMs'] as num?)?.toInt() ?? 0;

  /// Maps event type to the corresponding [SOSNativeState].
  SOSNativeState get nativeState => switch (type) {
        SOSEventName.sosStarted       => SOSNativeState.triggered,
        SOSEventName.bufferStarted    => SOSNativeState.buffer,
        SOSEventName.recordingStarted => SOSNativeState.recordingAudio,
        SOSEventName.videoStarted     => SOSNativeState.recordingVideo,
        SOSEventName.sessionEnded     => SOSNativeState.stopped,
        SOSEventName.cooldownStarted  => SOSNativeState.cooldown,
        SOSEventName.idle             => SOSNativeState.idle,
        _                             => SOSNativeState.unknown,
      };

  @override
  String toString() => 'SOSEvent($type, $payload)';
}

/// SOSPlatformService — Flutter-side wrapper for the native [sos_channel]
/// and [sos_events] channels.
///
/// This is the **only** Dart file that directly touches native channels.
/// All other Dart code (providers, screens) calls this service.
///
/// MethodChannel methods:
///   startSOS  → triggers SOS via Button source
///   stopSOS   → ends the active session ("I'm Safe")
///   getState  → returns the current SOSNativeState
///
/// EventChannel stream:
///   [stateStream] — emits [SOSEvent] for every native state transition.
class SOSPlatformService {
  SOSPlatformService._();

  static const _channel = MethodChannel('sos_channel');

  /// EventChannel that receives real-time SOS state transitions from Kotlin.
  static const _eventChannel = EventChannel('com.nexus.sheildai/sos_events');

  // ─── EventChannel stream ──────────────────────────────────────────────────

  /// Broadcast stream of [SOSEvent] objects pushed from the native state machine.
  ///
  /// Each emission corresponds to a state transition in [SOSManager.transitionTo].
  /// Listen to this instead of polling [getState] for responsive UI updates.
  static Stream<SOSEvent> get stateStream {
    return _eventChannel.receiveBroadcastStream().map((raw) {
      try {
        final map = Map<String, dynamic>.from(raw as Map);
        final type = map['event'] as String? ?? 'UNKNOWN';
        final payloadRaw = map['payload'];
        final payload = payloadRaw != null
            ? Map<String, dynamic>.from(payloadRaw as Map)
            : const <String, dynamic>{};
        final event = SOSEvent(type: type, payload: payload);
        debugPrint('[SOSPlatformService] ← event: $event');
        return event;
      } catch (e) {
        debugPrint('[SOSPlatformService] Failed to decode event: $e (raw: $raw)');
        return SOSEvent(type: 'UNKNOWN');
      }
    });
  }

  // ─── MethodChannel API ────────────────────────────────────────────────────

  /// Sends [startSOS] to the native layer.
  ///
  /// [contacts] — list of phone number strings to SMS during the SOS session.
  /// Pass an empty list to use the native default emergency numbers (100, 1091, 102).
  ///
  /// Returns the new [SOSNativeState] after the call.
  /// Never throws — errors are caught and logged.
  static Future<SOSNativeState> startSOS({List<String> contacts = const []}) async {
    try {
      final raw = await _channel.invokeMethod<String>('startSOS', {
        'contacts': contacts,
      });
      final state = SOSNativeState.fromString(raw);
      debugPrint('[SOSPlatformService] startSOS → $state (${contacts.length} contacts)');
      return state;
    } on PlatformException catch (e) {
      debugPrint('[SOSPlatformService] startSOS PlatformException: ${e.message}');
      return SOSNativeState.unknown;
    } catch (e) {
      debugPrint('[SOSPlatformService] startSOS error: $e');
      return SOSNativeState.unknown;
    }
  }

  /// Sends [stopSOS] to the native layer ("I'm Safe").
  ///
  /// Returns the new [SOSNativeState] after the call.
  /// Never throws — errors are caught and logged.
  static Future<SOSNativeState> stopSOS() async {
    try {
      final raw = await _channel.invokeMethod<String>('stopSOS');
      final state = SOSNativeState.fromString(raw);
      debugPrint('[SOSPlatformService] stopSOS → $state');
      return state;
    } on PlatformException catch (e) {
      debugPrint('[SOSPlatformService] stopSOS PlatformException: ${e.message}');
      return SOSNativeState.unknown;
    } catch (e) {
      debugPrint('[SOSPlatformService] stopSOS error: $e');
      return SOSNativeState.unknown;
    }
  }

  /// Queries the current native SOS state without triggering a transition.
  static Future<SOSNativeState> getState() async {
    try {
      final raw = await _channel.invokeMethod<String>('getState');
      return SOSNativeState.fromString(raw);
    } catch (e) {
      debugPrint('[SOSPlatformService] getState error: $e');
      return SOSNativeState.unknown;
    }
  }

  // ─── Voice Detection ──────────────────────────────────────────────────────

  /// Starts the always-on [VoiceDetectionService].
  ///
  /// On first call: downloads the Vosk model (~40 MB) and caches it.
  /// Subsequent calls use the cached model — no internet needed.
  ///
  /// The service runs with START_STICKY so it restarts after process death.
  static Future<void> enableVoiceDetection() async {
    try {
      await _channel.invokeMethod<bool>('enableVoice');
      debugPrint('[SOSPlatformService] Voice detection enabled');
    } catch (e) {
      debugPrint('[SOSPlatformService] enableVoiceDetection error: $e');
    }
  }

  /// Stops the [VoiceDetectionService] and releases the microphone.
  static Future<void> disableVoiceDetection() async {
    try {
      await _channel.invokeMethod<bool>('disableVoice');
      debugPrint('[SOSPlatformService] Voice detection disabled');
    } catch (e) {
      debugPrint('[SOSPlatformService] disableVoiceDetection error: $e');
    }
  }

  /// Returns true if the voice detection service is currently listening.
  static Future<bool> isVoiceDetectionActive() async {
    try {
      return await _channel.invokeMethod<bool>('isVoiceActive') ?? false;
    } catch (e) {
      return false;
    }
  }
}
