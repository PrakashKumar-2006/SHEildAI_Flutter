# Bugfix Requirements Document

## Introduction

When an SOS session is triggered, the app should record video using both the front and rear cameras simultaneously, composited into a single split-screen MP4 (front on top, rear on bottom). Instead, only the front camera is recorded. The dual-camera recording engine (`DualCameraRecorder`) exists and is fully functional but is never invoked during SOS — `SOSManager` calls `VideoRecordingService`, which opens only a single camera. This means SOS evidence footage lacks the rear-facing perspective, reducing situational context captured during an emergency.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN an SOS session is triggered and the app is in the foreground THEN the system starts `VideoRecordingService`, which opens only the front camera (falling back to the rear camera if the front is unavailable), producing a single-camera recording.

1.2 WHEN `SOSManager.performVideoEscalation()` is called THEN the system invokes `VideoRecordingService.startRecording()` and never calls `DualCameraRecorder`, so the concurrent front+back camera pipeline is never activated during SOS.

1.3 WHEN the device supports concurrent front and rear camera access THEN the system ignores that capability during SOS and records from only one camera.

### Expected Behavior (Correct)

2.1 WHEN an SOS session is triggered and the app is in the foreground and the device supports concurrent camera access THEN the system SHALL start a dual-camera recording that composites the front camera (top half) and rear camera (bottom half) into a single split-screen MP4 file.

2.2 WHEN `SOSManager.performVideoEscalation()` is called and the device supports concurrent camera access THEN the system SHALL invoke the dual-camera recording engine (equivalent to `DualCameraRecorder`) instead of the single-camera `VideoRecordingService`.

2.3 WHEN the device does not support concurrent camera access THEN the system SHALL fall back to the existing single-camera recording behaviour (front camera preferred, rear as fallback) so SOS recording always produces a video file.

### Unchanged Behavior (Regression Prevention)

3.1 WHEN an SOS session is triggered THEN the system SHALL CONTINUE TO transition through the state sequence IDLE → TRIGGERED → BUFFER → RECORDING_AUDIO → RECORDING_VIDEO without altering timing or state-machine logic.

3.2 WHEN the SOS buffer cancel-window is active THEN the system SHALL CONTINUE TO allow the user to cancel the session before recording begins.

3.3 WHEN an SOS session ends via `endSession()` or `cancelBuffer()` THEN the system SHALL CONTINUE TO stop all active recording services and transition to STOPPED → COOLDOWN → IDLE.

3.4 WHEN `AudioRecordingService` is running during the RECORDING_AUDIO phase THEN the system SHALL CONTINUE TO release the microphone before the video recording phase begins, preserving the 1-second mic handoff delay.

3.5 WHEN the app is in the background at the time of video escalation THEN the system SHALL CONTINUE TO skip video recording (foreground-only constraint) and audio-only SOS continues uninterrupted.

3.6 WHEN the SOS video recording is active THEN the system SHALL CONTINUE TO enforce the 2-minute maximum recording duration limit.

3.7 WHEN the standalone dual-camera test screen (`DualCameraScreen`) is used independently of SOS THEN the system SHALL CONTINUE TO operate exactly as before, with no change to its behaviour or the `DualCameraView` / `DualCameraController` integration.

---

### Bug Condition Derivation

**Bug Condition Function:**

```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type SOSVideoEscalationContext
  OUTPUT: boolean

  // The bug is triggered whenever SOS escalates to video recording
  // on a device that supports concurrent cameras — the dual-camera
  // engine should be used but is not.
  RETURN X.appIsInForeground = true
     AND X.deviceSupportsConcurrentCameras = true
     AND X.recordingEngine = SINGLE_CAMERA
END FUNCTION
```

**Property — Fix Checking:**

```pascal
// Property: Fix Checking — Dual Camera Used During SOS
FOR ALL X WHERE isBugCondition(X) DO
  result ← performVideoEscalation'(X)
  ASSERT result.recordingEngine = DUAL_CAMERA
     AND result.outputFile contains front_camera_stream
     AND result.outputFile contains rear_camera_stream
END FOR
```

**Property — Preservation Checking:**

```pascal
// Property: Preservation Checking
FOR ALL X WHERE NOT isBugCondition(X) DO
  // Devices without concurrent camera support, or background SOS sessions
  ASSERT performVideoEscalation(X) = performVideoEscalation'(X)
END FOR
```
