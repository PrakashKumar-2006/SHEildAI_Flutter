# SOS Dual-Camera Recording Bugfix Design

## Overview

During an SOS session, `SOSManager.performVideoEscalation()` calls
`VideoRecordingService.startRecording()`, which opens only a single camera (front preferred,
rear as fallback). The `DualCameraRecorder` engine — which composites front and rear cameras
into a single split-screen MP4 using CameraX's concurrent camera API — exists and works
correctly but is never invoked during SOS.

The fix modifies `VideoRecordingService` to:
1. Query `ProcessCameraProvider.availableConcurrentCameraInfos` at startup.
2. If the device supports simultaneous front + rear access, inline the concurrent camera
   binding logic (adapted from `DualCameraRecorder.bindConcurrentCamerasAndRecord()`) using
   an off-screen `SurfaceTexture`-backed surface instead of a `PreviewView`, since the
   service has no UI.
3. If the device does not support concurrent cameras, fall back to the existing single-camera
   path unchanged.

No changes are required to `SOSManager`, `DualCameraRecorder`, `DualCameraView`, or any
Flutter-side code.

---

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug — SOS video escalation is
  invoked on a device that supports concurrent front + rear camera access, yet only a
  single camera is recorded.
- **Property (P)**: The desired behavior when the bug condition holds — the output MP4
  contains a composited split-screen with the front camera on the top half and the rear
  camera on the bottom half.
- **Preservation**: All SOS behaviors that must remain unchanged by the fix — state
  transitions, timing, fallback recording, session teardown, and the standalone
  `DualCameraScreen` / `DualCameraView` integration.
- **`VideoRecordingService`**: The SOS foreground service in
  `android/app/src/main/kotlin/com/nexus/sheildai/sheild_ai/sos/VideoRecordingService.kt`
  that manages camera access and recording during the `RECORDING_VIDEO` SOS phase.
- **`DualCameraRecorder`**: The concurrent camera engine in
  `android/app/src/main/kotlin/com/nexus/sheildai/sheild_ai/dualcamera/DualCameraRecorder.kt`
  that uses CameraX `SingleCameraConfig` + `CompositionSettings` to produce a 720×1440
  split-screen MP4.
- **`SOSManager.performVideoEscalation()`**: The private function in `SosManager.kt` that
  stops audio recording and calls `VideoRecordingService.startRecording()`.
- **`ServiceLifecycleOwner`**: The minimal `LifecycleOwner` inner class inside
  `VideoRecordingService` that drives CameraX without an Activity.
- **`RecorderLifecycleOwner`**: The equivalent minimal `LifecycleOwner` inside
  `DualCameraRecorder` — same pattern, different class name.
- **`availableConcurrentCameraInfos`**: The CameraX API on `ProcessCameraProvider` that
  returns sets of cameras that can be opened simultaneously on the device ISP.
- **`SurfaceTexture` / off-screen surface**: A GPU texture surface that can receive camera
  frames without a visible `View`, used here to satisfy the CameraX `Preview` use-case
  surface requirement in a headless service context.
- **`CompositionSettings`**: CameraX API that maps each camera stream to a normalised
  sub-region of the shared output surface (offset + scale in 0.0–1.0 coordinates).

---

## Bug Details

### Bug Condition

The bug manifests whenever `SOSManager.performVideoEscalation()` is called on a device
whose ISP supports concurrent front + rear camera access. `VideoRecordingService.setupCameraAndRecord()`
unconditionally selects a single `CameraSelector` (front preferred, rear fallback) and
calls `provider.bindToLifecycle(lifecycleOwner, cameraSelector, videoCapture)` — the
single-camera overload. The concurrent binding path (`provider.bindToLifecycle(List<SingleCameraConfig>)`)
is never reached.

**Formal Specification:**

```
FUNCTION isBugCondition(X)
  INPUT:  X of type SOSVideoEscalationContext
  OUTPUT: boolean

  RETURN X.appIsInForeground = true
     AND X.deviceSupportsConcurrentCameras = true
     AND X.recordingEngine = SINGLE_CAMERA
END FUNCTION
```

### Examples

- **Pixel 8 (foreground SOS)**: Device supports concurrent cameras. SOS triggers, app is
  in foreground. Expected: 720×1440 split-screen MP4 with front (top) + rear (bottom).
  Actual: single front-camera 720p MP4.

- **Galaxy S24 (foreground SOS)**: Same as above — concurrent cameras supported, only
  front camera recorded.

- **Older device without concurrent support (foreground SOS)**: `availableConcurrentCameraInfos`
  returns no set containing both FRONT and BACK. Expected: single front-camera recording
  (fallback path). Actual: same single front-camera recording — no regression.

- **Background SOS (any device)**: `VideoRecordingService.handleStart()` catches the
  `SecurityException` from `startForeground()` and calls `stopSelf()`. Expected: no video
  recording, audio SOS continues. Actual: same — no regression.

---

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**

- The SOS state machine IDLE → TRIGGERED → BUFFER → RECORDING_AUDIO → RECORDING_VIDEO
  sequence and all timing must remain identical.
- The 1-second mic handoff delay inside `performVideoEscalation()` must remain unchanged.
- The 2-minute maximum recording duration limit (`MAX_RECORDING_DURATION_MS`) must be
  enforced for both single-camera and dual-camera paths.
- The background-SOS guard (`SecurityException` catch on `startForeground()`) must
  continue to prevent video recording when the app is in the background.
- `endSession()` and `cancelBuffer()` must continue to stop video recording correctly
  via `VideoRecordingService.stopRecording(context)`.
- The standalone `DualCameraScreen` / `DualCameraView` / `DualCameraRecorder` integration
  must be completely unaffected — no changes to those classes.
- The wake lock, notification, and `ServiceLifecycleOwner` behaviour must remain unchanged.
- On devices that do not support concurrent cameras, the existing single-camera recording
  path must produce identical output to the pre-fix behaviour.

**Scope:**

All inputs where `isBugCondition(X)` is false — devices without concurrent camera support,
background SOS sessions, or any non-SOS code path — must be completely unaffected by this
fix.

---

## Hypothesized Root Cause

Based on code inspection, the root cause is a **missing code path** rather than a logic
error in existing code:

1. **`VideoRecordingService` never calls the concurrent binding API**: `setupCameraAndRecord()`
   calls `provider.bindToLifecycle(lifecycleOwner, cameraSelector, videoCapture)` — the
   single-camera overload. The concurrent overload
   `provider.bindToLifecycle(List<SingleCameraConfig>)` is never called anywhere in the
   service.

2. **`DualCameraRecorder` requires a `PreviewView`**: The constructor signature is
   `DualCameraRecorder(context, previewView)`. `VideoRecordingService` has no `View`
   hierarchy, so it cannot instantiate `DualCameraRecorder` directly. This is the
   architectural gap that prevented the dual-camera path from being wired up.

3. **No capability check at escalation time**: `performVideoEscalation()` in `SosManager.kt`
   calls `VideoRecordingService.startRecording(context)` unconditionally without first
   checking `availableConcurrentCameraInfos`. The capability check must happen inside
   `VideoRecordingService` itself (after `ProcessCameraProvider` is available) to keep
   `SOSManager` decoupled from camera hardware details.

4. **`Preview` use-case surface requirement**: CameraX's concurrent camera binding still
   requires a `Preview` use-case with a valid surface provider. In `DualCameraRecorder`
   this is satisfied by `previewView.surfaceProvider`. In a headless service, an
   off-screen `SurfaceTexture` (wrapped in a `SurfaceRequest` callback) must be used
   instead.

---

## Correctness Properties

Property 1: Bug Condition — Dual Camera Used During SOS on Supported Devices

_For any_ `SOSVideoEscalationContext` X where `isBugCondition(X)` returns true (app is in
foreground, device supports concurrent front + rear cameras, and the recording engine was
previously single-camera), the fixed `VideoRecordingService` SHALL start a concurrent
dual-camera recording session that composites the front camera stream into the top half
and the rear camera stream into the bottom half of a single 720×1440 MP4 output file.

**Validates: Requirements 2.1, 2.2**

Property 2: Preservation — Single-Camera Fallback and All Non-Buggy Paths Unchanged

_For any_ `SOSVideoEscalationContext` X where `isBugCondition(X)` returns false (device
does not support concurrent cameras, or app is in the background), the fixed
`VideoRecordingService` SHALL produce exactly the same recording behaviour as the original
`VideoRecordingService`, preserving the single-camera fallback path, background-SOS guard,
state machine transitions, timing, duration limit, and all other SOS session behaviours.

**Validates: Requirements 2.3, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**

---

## Fix Implementation

### Changes Required

**File**: `android/app/src/main/kotlin/com/nexus/sheildai/sheild_ai/sos/VideoRecordingService.kt`

**Function**: `setupCameraAndRecord()` (and a new private helper)

#### Specific Changes

1. **Add concurrent camera capability check** inside the `cameraProviderFuture.addListener`
   callback, after `cameraProvider = provider`:
   - Call `provider.availableConcurrentCameraInfos` and check whether any set contains
     both a `LENS_FACING_FRONT` and a `LENS_FACING_BACK` camera info.
   - Store the result in a local `val supportsDualCamera: Boolean`.

2. **Branch on `supportsDualCamera`**:
   - `true` → call new private function `setupDualCameraAndRecord(provider, videoCapture)`
   - `false` → execute the existing single-camera binding path unchanged

3. **Add `setupDualCameraAndRecord(provider, videoCapture)` private function**:
   - Create a shared `Recorder` with the same `QualitySelector` as the existing path.
   - Create a `VideoCapture.withOutput(recorder)`.
   - Create a `Preview.Builder().build()`.
   - Create an off-screen `SurfaceTexture(0)` and attach it as the `Preview` surface
     provider via `preview.setSurfaceProvider { request -> ... }` — the `SurfaceTexture`
     satisfies CameraX's surface requirement without a visible `View`.
   - Build `CompositionSettings` for front (offset 0,0 / scale 1×0.5) and rear
     (offset 0,0.5 / scale 1×0.5) — identical to `DualCameraRecorder`.
   - Build `SingleCameraConfig` for front and rear cameras, both sharing the same
     `UseCaseGroup` (preview + videoCapture) and the service's `lifecycleOwner`.
   - Call `provider.bindToLifecycle(listOf(frontConfig, backConfig))`.
   - Call `startRecordingToMediaStore(videoCapture)` — reuse the existing method unchanged.

4. **`ServiceLifecycleOwner.start()` fix**: The existing `start()` sets state to
   `Lifecycle.State.STARTED` (not `RESUMED`). CameraX requires `RESUMED` to open cameras.
   Change `start()` to set `registry.currentState = Lifecycle.State.RESUMED` to match
   `DualCameraRecorder.RecorderLifecycleOwner.start()`.

5. **`SurfaceTexture` cleanup**: Store the off-screen `SurfaceTexture` as an instance
   field and call `surfaceTexture.release()` inside `releaseCamera()` to prevent GPU
   texture leaks.

#### What Does NOT Change

- `SOSManager.performVideoEscalation()` — no changes needed.
- `DualCameraRecorder` — not modified; its `PreviewView`-based path is preserved for
  `DualCameraView` / `DualCameraScreen`.
- `startRecordingToMediaStore()` — reused as-is for both paths.
- `handleStart()`, `handleStop()`, `startDurationTimer()`, wake lock, notification — all
  unchanged.
- All Flutter-side files — no changes.

---

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that
demonstrate the bug on unfixed code to confirm the root cause; then verify the fix works
correctly and preserves all existing behaviour.

---

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix.
Confirm or refute the root cause analysis. If refuted, re-hypothesize.

**Test Plan**: Write instrumented tests (or Robolectric unit tests with a mocked
`ProcessCameraProvider`) that simulate an SOS video escalation on a device that reports
concurrent camera support. Assert that the concurrent binding overload
(`provider.bindToLifecycle(List<SingleCameraConfig>)`) is called. Run these tests on the
UNFIXED code to observe failures.

**Test Cases**:

1. **Concurrent binding not called (unfixed)**: Mock `ProcessCameraProvider` to report
   concurrent support. Start `VideoRecordingService` with `ACTION_START`. Assert that
   `provider.bindToLifecycle(List<SingleCameraConfig>)` was invoked. Expected: FAILS on
   unfixed code — the single-camera overload is called instead.

2. **Single-camera overload called on concurrent-capable device (unfixed)**: Same setup.
   Assert that `provider.bindToLifecycle(LifecycleOwner, CameraSelector, VideoCapture)`
   is called. Expected: PASSES on unfixed code — confirms the bug.

3. **Output file contains only one camera stream (unfixed)**: On a real concurrent-capable
   device, trigger SOS video escalation and inspect the output MP4 metadata. Expected:
   single-camera resolution (e.g., 1280×720), not the dual-camera 720×1440 composite.

4. **Fallback path on non-concurrent device (unfixed)**: Mock `ProcessCameraProvider` to
   report no concurrent support. Assert single-camera binding is used. Expected: PASSES
   on unfixed code — confirms the fallback path is already correct.

**Expected Counterexamples**:
- The concurrent binding API is never called during SOS on concurrent-capable devices.
- Root cause confirmed: missing capability check + missing concurrent binding path in
  `VideoRecordingService`.

---

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed
`VideoRecordingService` produces the expected dual-camera output.

**Pseudocode:**

```
FOR ALL X WHERE isBugCondition(X) DO
  result := VideoRecordingService_fixed.startRecording(X)
  ASSERT result.bindingType = CONCURRENT
     AND result.outputFile.resolution = "720x1440"
     AND result.outputFile.containsFrontCameraStream = true
     AND result.outputFile.containsRearCameraStream = true
END FOR
```

**Test Cases**:

1. **Concurrent binding called on concurrent-capable device (fixed)**: Mock
   `ProcessCameraProvider` to report concurrent support. Start fixed service. Assert
   `provider.bindToLifecycle(List<SingleCameraConfig>)` is called with two configs —
   one `DEFAULT_FRONT_CAMERA` and one `DEFAULT_BACK_CAMERA`.

2. **Correct `CompositionSettings` applied (fixed)**: Assert front config has
   `CompositionSettings` with offset (0,0) and scale (1.0, 0.5); rear config has
   offset (0, 0.5) and scale (1.0, 0.5).

3. **Output file produced on real device (fixed)**: On a concurrent-capable device,
   trigger SOS video escalation and verify the output MP4 is 720×1440 and contains
   two visually distinct camera streams.

4. **Duration limit still enforced (fixed)**: Verify the 2-minute timer fires and
   calls `handleStop()` on the dual-camera path.

---

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed
`VideoRecordingService` produces the same result as the original.

**Pseudocode:**

```
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT VideoRecordingService_original(X) = VideoRecordingService_fixed(X)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking
because it generates many test cases automatically across the input domain, catches edge
cases that manual unit tests might miss, and provides strong guarantees that behaviour is
unchanged for all non-buggy inputs.

**Test Cases**:

1. **Single-camera fallback preserved**: Mock `ProcessCameraProvider` to report no
   concurrent support. Assert the fixed service calls the single-camera binding overload
   and produces a single-camera MP4 — identical to the original behaviour.

2. **Background SOS guard preserved**: Simulate `startForeground()` throwing
   `SecurityException`. Assert the fixed service calls `stopSelf()` and does not attempt
   camera binding — identical to the original behaviour.

3. **`endSession()` teardown preserved**: Start the fixed service (dual-camera path),
   then call `VideoRecordingService.stopRecording(context)`. Assert `activeRecording.stop()`
   is called and the service stops cleanly.

4. **2-minute limit preserved on single-camera path**: On a non-concurrent device, verify
   the duration timer fires at `MAX_RECORDING_DURATION_MS` and stops recording.

5. **`DualCameraScreen` unaffected**: Verify `DualCameraRecorder` and `DualCameraView`
   compile and function identically — no source changes, no import changes.

---

### Unit Tests

- Test `isConcurrentCameraSupported()` logic (extracted or inlined) with mocked
  `ProcessCameraProvider` returning various `availableConcurrentCameraInfos` configurations.
- Test that `setupDualCameraAndRecord()` builds `SingleCameraConfig` with correct
  `CompositionSettings` offsets and scales.
- Test that `setupCameraAndRecord()` branches correctly: concurrent path when supported,
  single-camera path when not.
- Test `ServiceLifecycleOwner.start()` sets state to `RESUMED` (not `STARTED`).
- Test `SurfaceTexture` is released in `releaseCamera()`.

### Property-Based Tests

- Generate random `SOSVideoEscalationContext` values where `isBugCondition` is true and
  verify the fixed service always selects the concurrent binding path.
- Generate random `SOSVideoEscalationContext` values where `isBugCondition` is false and
  verify the fixed service always selects the single-camera binding path.
- Generate random recording durations and verify the 2-minute cap is enforced on both
  paths.

### Integration Tests

- Full SOS flow on a concurrent-capable device: trigger SOS, wait for video escalation,
  verify the output MP4 is 720×1440 with both camera streams visible.
- Full SOS flow on a non-concurrent device: verify single-camera MP4 is produced and
  the session ends cleanly.
- `endSession()` during dual-camera recording: verify the service stops, the file is
  finalised, and the SOS state machine transitions to STOPPED → COOLDOWN → IDLE.
- App backgrounded during dual-camera recording: verify the foreground service continues
  (wake lock held) and the 2-minute limit is still enforced.
