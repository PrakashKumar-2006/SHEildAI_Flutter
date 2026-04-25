import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/sos_platform_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../data/repositories/sos_repository_impl.dart';
import '../../domain/models/sos_model.dart';
import '../../../location/presentation/providers/location_provider.dart';

class SOSProvider extends ChangeNotifier {
  final SOSRepositoryImpl _sosRepository;
  final LocationService _locationService;
  final LocationProvider _locationProvider;

  SOSModel? _activeSOS;
  bool _isLoading = false;
  String? _errorMessage;
  String _sessionDuration = '00:00';
  String _currentLocation = 'Current Location';

  /// Native SOS state driven by the real-time EventChannel stream.
  SOSNativeState _nativeState = SOSNativeState.idle;

  /// Seconds remaining in the buffer cancel-window countdown.
  /// Non-null only while [_nativeState] == buffer.
  int? _bufferSecondsRemaining;

  /// Seconds remaining in the post-session cooldown.
  /// Non-null only while [_nativeState] == cooldown.
  int? _cooldownSecondsRemaining;

  // ─── Timers ──────────────────────────────────────────────────────────────

  Timer? _bufferTimer;
  Timer? _cooldownTimer;
  Timer? _durationTimer;

  // ─── Stream subscription ─────────────────────────────────────────────────

  StreamSubscription<SOSEvent>? _eventSub;

  SOSProvider({
    required SOSRepositoryImpl sosRepository,
    required LocationService locationService,
    required LocationProvider locationProvider,
  })  : _sosRepository = sosRepository,
        _locationService = locationService,
        _locationProvider = locationProvider {
    _subscribeToNativeEvents();
  }

  // ─── Getters ──────────────────────────────────────────────────────────────

  SOSModel? get activeSOS => _activeSOS;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSOSActive => _activeSOS != null;
  String get sessionDuration => _sessionDuration;
  String get currentLocation => _currentLocation;

  /// Native state from Kotlin SOSManager (reflects the Android-side state machine).
  SOSNativeState get nativeState => _nativeState;

  /// True when the native layer has an active session.
  bool get isNativeSOSActive => _nativeState.isActive;

  /// True while the buffer cancel-window is counting down.
  bool get isInBuffer => _nativeState == SOSNativeState.buffer;

  /// True while the post-session cooldown is running.
  bool get isInCooldown => _nativeState == SOSNativeState.cooldown;

  /// Seconds left in the buffer cancel window (null when not in buffer).
  int? get bufferSecondsRemaining => _bufferSecondsRemaining;

  /// Seconds left in the cooldown period (null when not in cooldown).
  int? get cooldownSecondsRemaining => _cooldownSecondsRemaining;

  // ─── EventChannel subscription ────────────────────────────────────────────

  /// Subscribes to the native EventChannel stream and reacts to every event.
  void _subscribeToNativeEvents() {
    _eventSub = SOSPlatformService.stateStream.listen(
      _onNativeEvent,
      onError: (e) {
        debugPrint('[SOSProvider] EventChannel error: $e');
      },
    );
  }

  void _onNativeEvent(SOSEvent event) {
    debugPrint('[SOSProvider] Native event: $event');

    // Update the state immediately (triggers UI rebuild)
    _nativeState = event.nativeState;

    switch (event.type) {
      case SOSEventName.bufferStarted:
        _startBufferCountdown(event.bufferMs);

      case SOSEventName.recordingStarted:
      case SOSEventName.videoStarted:
        _cancelBufferTimer();

      case SOSEventName.sessionEnded:
        _cancelBufferTimer();
        _cancelCooldownTimer();

      case SOSEventName.cooldownStarted:
        _startCooldownCountdown(event.cooldownMs);

      case SOSEventName.idle:
        _cancelCooldownTimer();
    }

    notifyListeners();
  }

  // ─── Countdown timers ─────────────────────────────────────────────────────

  void _startBufferCountdown(int bufferMs) {
    _cancelBufferTimer();
    _bufferSecondsRemaining = (bufferMs / 1000).ceil();

    _bufferTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = (_bufferSecondsRemaining ?? 0) - 1;
      if (remaining <= 0) {
        _bufferSecondsRemaining = null;
        timer.cancel();
      } else {
        _bufferSecondsRemaining = remaining;
      }
      notifyListeners();
    });
  }

  void _cancelBufferTimer() {
    _bufferTimer?.cancel();
    _bufferTimer = null;
    _bufferSecondsRemaining = null;
  }

  void _startCooldownCountdown(int cooldownMs) {
    _cancelCooldownTimer();
    _cooldownSecondsRemaining = (cooldownMs / 1000).ceil();

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = (_cooldownSecondsRemaining ?? 0) - 1;
      if (remaining <= 0) {
        _cooldownSecondsRemaining = null;
        timer.cancel();
      } else {
        _cooldownSecondsRemaining = remaining;
      }
      notifyListeners();
    });
  }

  void _cancelCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _cooldownSecondsRemaining = null;
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  Future<void> triggerSOS({
    List<String>? customContacts,
    String? customMessage,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Resolve contacts early — passed to native layer for SMS dispatch
    final contacts = customContacts ?? StorageService().getTrustedContacts();

    // 1. Fire native SOS — this is immediate and does not await location.
    //    The EventChannel will push subsequent state changes automatically.
    final nativeResult = await SOSPlatformService.startSOS(contacts: contacts);
    _nativeState = nativeResult;
    debugPrint('[SOSProvider] Native channel response: ${nativeResult.displayName}');

    try {
      // 2. Get current location (may take a moment)
      final position = await _locationService.getCurrentPosition();

      // 3. Persist SOS event via repository
      final result = await _sosRepository.triggerSOS(
        latitude: position.latitude,
        longitude: position.longitude,
        contacts: contacts,
        message: customMessage,
      );

      result.fold(
        (failure) {
          _errorMessage = failure.toString();
          _isLoading = false;
          notifyListeners();
        },
        (sos) {
          _activeSOS = sos;
          _isLoading = false;
          // Start background location tracking during SOS
          _locationProvider.startTracking(background: true);
          _startDurationTimer();
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cancelSOS() async {
    if (_activeSOS == null) {
      // Still attempt native stop — user may have triggered via voice
      _nativeState = await SOSPlatformService.stopSOS();
      debugPrint('[SOSProvider] cancelSOS (no Flutter model) — native: ${_nativeState.displayName}');
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    // Fire native stop first (immediate)
    _nativeState = await SOSPlatformService.stopSOS();
    debugPrint('[SOSProvider] Native stopSOS response: ${_nativeState.displayName}');

    try {
      await _sosRepository.cancelSOS(_activeSOS!.id);
      _activeSOS = null;
      _isLoading = false;
      _durationTimer?.cancel();
      // Stop background location tracking
      await _locationProvider.stopTracking();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkSOSStatus() async {
    final result = await _sosRepository.isSOSActive();
    result.fold(
      (failure) => null,
      (isActive) {
        if (!isActive && _activeSOS != null) {
          _activeSOS = null;
          notifyListeners();
        }
      },
    );
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Queries the native layer for the current SOS state and reconciles it
  /// with the local [_nativeState].
  ///
  /// Called by [SOSScreen] on [initState] (and on app-resume) as a safety net
  /// for the case where a voice-triggered SOS session began while the Flutter
  /// UI was not actively subscribed to the EventChannel.
  ///
  /// If a drift is detected (native state ≠ local state), the local state is
  /// updated and [notifyListeners] is called so the UI rebuilds immediately —
  /// enabling the "I'm Safe" button without requiring the user to navigate away.
  Future<void> syncWithNative() async {
    try {
      final nativeState = await SOSPlatformService.getState();
      if (nativeState != _nativeState) {
        debugPrint(
          '[SOSProvider] 🔄 State drift detected — '
          'native: ${nativeState.displayName}, local: ${_nativeState.displayName} — syncing',
        );
        _nativeState = nativeState;
        notifyListeners();
      } else {
        debugPrint('[SOSProvider] ✅ syncWithNative — in sync (${_nativeState.displayName})');
      }
    } catch (e) {
      debugPrint('[SOSProvider] syncWithNative error: $e');
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    final startTime = DateTime.now();

    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeSOS == null) {
        timer.cancel();
        return;
      }
      final duration = DateTime.now().difference(startTime);
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      _sessionDuration = '$minutes:$seconds';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _cancelBufferTimer();
    _cancelCooldownTimer();
    _durationTimer?.cancel();
    super.dispose();
  }
}
