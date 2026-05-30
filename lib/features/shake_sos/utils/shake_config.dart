class ShakeConfig {
  /// Acceleration threshold to detect a shake (m/s²).
  /// 12.0 - 15.0 is recommended for rapid shaking.
  static const double shakeThreshold = 14.0;

  /// Minimum number of shakes to trigger SOS.
  static const int minShakeCount = 3;

  /// Time window to detect the shakes (milliseconds).
  static const int shakeWindowMs = 2000;

  /// Minimum interval between detected shakes to count as separate shakes (milliseconds).
  static const int minShakeIntervalMs = 250;

  /// Cooldown after a successful SOS trigger to prevent multiple triggers (seconds).
  static const int triggerCooldownSeconds = 20;

  /// Whether to show a countdown dialog before triggering SOS.
  static const bool useCountdown = true;

  /// Countdown duration (seconds).
  static const int countdownDuration = 3;
}
