# Implementation Plan

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Single-Camera Binding Used on Concurrent-Capable Device
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior — it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate that `VideoRecordingService` calls the single-camera `bindToLifecycle` overload instead of the concurrent overload on a device that reports concurrent front+rear camera support
  - **Scoped PBT Approach**: Scope the property to the concrete failing case — `isBugCondition(X)` where `X.appIsInForeground = true`, `X.deviceSupportsConcurrentCameras = true`, and `X.recordingEngine = SINGLE_CAMERA`
  - Write an instrumented or Robolectric test that mocks `ProcessCameraProvider` to return a non-empty `availableConcurrentCameraInfos` list containing a set with both `LENS_FACING_FRONT` and `LENS_FACING_BACK` camera infos
  - Start `VideoRecordingService` with `ACTION_START` using the mocked provider
  - Assert that `provider.bindToLifecycle(List<SingleCameraConfig>)` (the concurrent overload) is called — this assertion should FAIL on unfixed code
  - Also assert that `provider.bindToLifecycle(LifecycleOwner, CameraSelector, VideoCapture)` (the single-camera overload) is NOT called — this assertion should also FAIL on unfixed code
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct — it proves the bug exists)
  - Document counterexamples found, e.g. "On a concurrent-capable device, `bindToLifecycle(LifecycleOwner, CameraSelector, VideoCapture)` is called instead of `bindToLifecycle(List<SingleCameraConfig>)`"
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Non-Buggy Paths Produce Identical Behaviour
  - **IMPORTANT**: Follow observation-first methodology — run the UNFIXED code with non-buggy inputs and record actual outputs before writing assertions
  - **Non-buggy inputs** are all `SOSVideoEscalationContext` X where `isBugCondition(X)` is false: devices without concurrent camera support, background SOS sessions, or any non-SOS code path
  - Observe on UNFIXED code:
    - When `availableConcurrentCameraInfos` returns an empty list or no set containing both FRONT and BACK, `VideoRecordingService` calls the single-camera `bindToLifecycle` overload — record this as the baseline
    - When `startForeground()` throws `SecurityException` (background SOS), the service calls `stopSelf()` and does not attempt any camera binding — record this as the baseline
    - When `VideoRecordingService.stopRecording(context)` is called, `activeRecording.stop()` is invoked and the service stops cleanly — record this as the baseline
    - The 2-minute duration timer fires at `MAX_RECORDING_DURATION_MS` and calls `handleStop()` on the single-camera path — record this as the baseline
  - Write property-based tests capturing these observed behaviors:
    - **PBT 2a**: For all `ProcessCameraProvider` configurations where no concurrent front+rear set exists, the fixed service calls the single-camera binding overload (identical to original)
    - **PBT 2b**: For all simulated background-SOS inputs (SecurityException on startForeground), the fixed service calls `stopSelf()` and does not bind any camera
    - **PBT 2c**: For all recording durations up to `MAX_RECORDING_DURATION_MS`, the duration timer fires and stops recording at the 2-minute cap on the single-camera path
    - **PBT 2d**: `DualCameraRecorder` and `DualCameraView` compile and function identically — no source changes, no import changes
  - Verify all tests PASS on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 2.3, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [ ] 3. Fix VideoRecordingService for dual-camera SOS recording

  - [x] 3.1 Fix `ServiceLifecycleOwner.start()` to set `Lifecycle.State.RESUMED`
    - In `VideoRecordingService.kt`, locate the `ServiceLifecycleOwner` inner class
    - Change `registry.currentState = Lifecycle.State.STARTED` to `registry.currentState = Lifecycle.State.RESUMED` in the `start()` function
    - This matches `DualCameraRecorder.RecorderLifecycleOwner.start()` and is required for CameraX to open cameras on both the single-camera and dual-camera paths
    - _Bug_Condition: isBugCondition(X) where X.recordingEngine = SINGLE_CAMERA on a concurrent-capable device_
    - _Expected_Behavior: ServiceLifecycleOwner.start() sets RESUMED so CameraX can open cameras_
    - _Preservation: Single-camera path also benefits — no regression_
    - _Requirements: 2.1, 2.2_

  - [x] 3.2 Add `SurfaceTexture` instance field to `VideoRecordingService`
    - Add `private var offScreenSurfaceTexture: SurfaceTexture? = null` as an instance field
    - This field will hold the off-screen texture created in `setupDualCameraAndRecord()` and must be released in `releaseCamera()` to prevent GPU texture leaks
    - _Requirements: 2.1_

  - [x] 3.3 Add concurrent camera capability check inside `setupCameraAndRecord()`
    - Inside the `cameraProviderFuture.addListener` callback, after `cameraProvider = provider`, add:
      ```kotlin
      val supportsDualCamera = provider.availableConcurrentCameraInfos.any { cameraInfoSet ->
          val hasFront = cameraInfoSet.any { it.lensFacing == CameraSelector.LENS_FACING_FRONT }
          val hasBack  = cameraInfoSet.any { it.lensFacing == CameraSelector.LENS_FACING_BACK }
          hasFront && hasBack
      }
      ```
    - Branch on `supportsDualCamera`: if `true` call `setupDualCameraAndRecord(provider)`, if `false` execute the existing single-camera binding path unchanged
    - Remove the existing unconditional single-camera binding block from the top-level flow and place it inside the `else` branch
    - _Bug_Condition: isBugCondition(X) where X.deviceSupportsConcurrentCameras = true_
    - _Expected_Behavior: concurrent binding path is selected when device supports it_
    - _Preservation: single-camera path is unchanged for non-concurrent devices_
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 3.4 Add `setupDualCameraAndRecord(provider: ProcessCameraProvider)` private function
    - Create a shared `Recorder` with the same `QualitySelector` as the existing single-camera path (HD with SD fallback)
    - Create `VideoCapture.withOutput(recorder)`
    - Create `Preview.Builder().build()`
    - Create an off-screen `SurfaceTexture(0)`, assign it to `offScreenSurfaceTexture`, and attach it as the Preview surface provider:
      ```kotlin
      val surfaceTexture = SurfaceTexture(0).also { offScreenSurfaceTexture = it }
      preview.setSurfaceProvider { request ->
          val surface = Surface(surfaceTexture)
          request.provideSurface(surface, ContextCompat.getMainExecutor(this)) { surface.release() }
      }
      ```
    - Build `CompositionSettings` for front camera: `setOffset(0.0f, 0.0f)`, `setScale(1.0f, 0.5f)` (top half)
    - Build `CompositionSettings` for rear camera: `setOffset(0.0f, 0.5f)`, `setScale(1.0f, 0.5f)` (bottom half)
    - Build `UseCaseGroup` containing both `preview` and `videoCapture`
    - Build `SingleCameraConfig` for front camera (`DEFAULT_FRONT_CAMERA`, `useCaseGroup`, `frontComposition`, `lifecycleOwner`)
    - Build `SingleCameraConfig` for rear camera (`DEFAULT_BACK_CAMERA`, `useCaseGroup`, `backComposition`, `lifecycleOwner`)
    - Call `provider.unbindAll()`, then `lifecycleOwner.start()`, then `provider.bindToLifecycle(listOf(frontConfig, backConfig))`
    - Call `startRecordingToMediaStore(videoCapture)` — reuse the existing method unchanged
    - _Bug_Condition: isBugCondition(X) where X.deviceSupportsConcurrentCameras = true AND X.recordingEngine = SINGLE_CAMERA_
    - _Expected_Behavior: provider.bindToLifecycle(listOf(frontConfig, backConfig)) is called; output MP4 contains front (top half) and rear (bottom half) streams_
    - _Preservation: startRecordingToMediaStore() is reused unchanged; duration timer, wake lock, and notification are unaffected_
    - _Requirements: 2.1, 2.2, 3.6_

  - [x] 3.5 Release `SurfaceTexture` in `releaseCamera()`
    - Inside `releaseCamera()`, after `cameraProvider?.unbindAll()`, add:
      ```kotlin
      offScreenSurfaceTexture?.release()
      offScreenSurfaceTexture = null
      ```
    - This prevents GPU texture leaks when the service is stopped or destroyed
    - _Requirements: 2.1_

  - [-] 3.6 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Concurrent Binding Called on Concurrent-Capable Device
    - **IMPORTANT**: Re-run the SAME test from task 1 — do NOT write a new test
    - The test from task 1 asserts that `provider.bindToLifecycle(List<SingleCameraConfig>)` is called with two `SingleCameraConfig` objects — one for `DEFAULT_FRONT_CAMERA` and one for `DEFAULT_BACK_CAMERA`
    - When this test passes, it confirms the concurrent binding path is now correctly selected
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: 2.1, 2.2_

  - [ ] 3.7 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Buggy Paths Unchanged After Fix
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Run all preservation property tests from step 2 (PBT 2a through 2d)
    - **EXPECTED OUTCOME**: All tests PASS (confirms no regressions on single-camera fallback, background guard, duration limit, and DualCameraScreen independence)
    - Confirm all tests still pass after fix

- [ ] 4. Checkpoint — Ensure all tests pass
  - Run the full test suite for `VideoRecordingService` and related SOS components
  - Confirm Property 1 (bug condition exploration test) passes — concurrent binding is used on concurrent-capable devices
  - Confirm Property 2 (preservation tests) passes — single-camera fallback, background guard, duration limit, and DualCameraScreen are all unaffected
  - Confirm no compilation errors or lint warnings introduced in `VideoRecordingService.kt`
  - Ensure all tests pass; ask the user if questions arise
