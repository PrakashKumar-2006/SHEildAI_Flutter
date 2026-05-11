package com.nexus.sheildai.sheild_ai.sos

import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.ConcurrentCamera.SingleCameraConfig
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.lifecycle.LifecycleOwner
import androidx.test.core.app.ApplicationProvider
import com.google.common.util.concurrent.Futures
import org.junit.After
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentCaptor
import org.mockito.Mockito
import org.mockito.kotlin.any
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowApplication
import java.util.concurrent.Executor

/**
 * Bug Condition Exploration Test — Property 1
 *
 * **Validates: Requirements 1.1, 1.2, 1.3**
 *
 * This test encodes the EXPECTED (fixed) behavior and is run against UNFIXED code.
 * It MUST FAIL on unfixed code — failure confirms the bug exists.
 *
 * Bug Condition:
 *   isBugCondition(X) where:
 *     X.appIsInForeground = true
 *     X.deviceSupportsConcurrentCameras = true
 *     X.recordingEngine = SINGLE_CAMERA
 *
 * The unfixed VideoRecordingService.setupCameraAndRecord() unconditionally calls
 * provider.bindToLifecycle(LifecycleOwner, CameraSelector, VideoCapture) — the
 * single-camera overload — even when the device supports concurrent front+rear cameras.
 *
 * Expected (fixed) behavior:
 *   - provider.bindToLifecycle(List<SingleCameraConfig>) IS called (concurrent overload)
 *   - provider.bindToLifecycle(LifecycleOwner, CameraSelector, VideoCapture) is NOT called
 *
 * EXPECTED TEST OUTCOME: FAILS on unfixed code (this is correct — it proves the bug exists)
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [Build.VERSION_CODES.TIRAMISU], manifest = Config.NONE)
class VideoRecordingServiceBugConditionTest {

    private lateinit var context: Context
    private lateinit var mockProvider: ProcessCameraProvider

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()

        // Create a mock ProcessCameraProvider that reports concurrent front+rear support
        mockProvider = mock()

        // Build mock CameraInfo objects for front and rear cameras
        val frontCameraInfo: CameraInfo = mock()
        val backCameraInfo: CameraInfo = mock()
        whenever(frontCameraInfo.lensFacing).thenReturn(CameraSelector.LENS_FACING_FRONT)
        whenever(backCameraInfo.lensFacing).thenReturn(CameraSelector.LENS_FACING_BACK)

        // availableConcurrentCameraInfos returns a list containing one list with both
        // FRONT and BACK cameras — this simulates a concurrent-capable device
        val concurrentSet: List<CameraInfo> = listOf(frontCameraInfo, backCameraInfo)
        whenever(mockProvider.availableConcurrentCameraInfos).thenReturn(listOf(concurrentSet))

        // hasCamera returns true for both front and back
        whenever(mockProvider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)).thenReturn(true)
        whenever(mockProvider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA)).thenReturn(true)

        // unbindAll() is a no-op
        Mockito.doNothing().`when`(mockProvider).unbindAll()

        // bindToLifecycle (single-camera overload) returns a mock Camera
        val mockCamera: androidx.camera.core.Camera = mock()
        whenever(
            mockProvider.bindToLifecycle(
                any<LifecycleOwner>(),
                any<CameraSelector>(),
                any<androidx.camera.core.UseCase>()
            )
        ).thenReturn(mockCamera)

        // bindToLifecycle (concurrent overload) returns a mock ConcurrentCamera
        val mockConcurrentCamera: androidx.camera.core.ConcurrentCamera = mock()
        whenever(
            mockProvider.bindToLifecycle(any<List<SingleCameraConfig>>())
        ).thenReturn(mockConcurrentCamera)

        // Inject the mock provider into ProcessCameraProvider via Robolectric shadow
        // ProcessCameraProvider.getInstance() returns a ListenableFuture — we shadow it
        // by using the static injection mechanism
        injectMockCameraProvider(mockProvider)
    }

    @After
    fun tearDown() {
        // Reset the injected ProcessCameraProvider instance so tests don't bleed into each other
        try { ProcessCameraProvider.configureInstance(null) } catch (_: Exception) {}
        // Stop any running service
        try {
            val stopIntent = Intent(context, VideoRecordingService::class.java).apply {
                action = VideoRecordingService.ACTION_STOP
            }
            context.startService(stopIntent)
        } catch (_: Exception) {}
    }

    /**
     * Property 1: Bug Condition — Single-Camera Binding Used on Concurrent-Capable Device
     *
     * **Validates: Requirements 1.1, 1.2, 1.3**
     *
     * On a device that reports concurrent front+rear camera support, the fixed
     * VideoRecordingService MUST call the concurrent bindToLifecycle overload
     * (provider.bindToLifecycle(List<SingleCameraConfig>)) and MUST NOT call the
     * single-camera overload (provider.bindToLifecycle(LifecycleOwner, CameraSelector, VideoCapture)).
     *
     * EXPECTED OUTCOME ON UNFIXED CODE: FAILS
     * Counterexample: provider.bindToLifecycle(LifecycleOwner, CameraSelector, VideoCapture)
     * is called instead of provider.bindToLifecycle(List<SingleCameraConfig>).
     */
    @Test
    fun `on concurrent-capable device SOS uses concurrent bindToLifecycle overload not single-camera overload`() {
        // Arrange: service controller for VideoRecordingService
        val serviceController = Robolectric.buildService(VideoRecordingService::class.java)
        val service = serviceController.create().get()

        // Act: send ACTION_START to simulate SOS video escalation
        // (app is in foreground — startForeground() will succeed under Robolectric)
        val startIntent = Intent(context, VideoRecordingService::class.java).apply {
            action = VideoRecordingService.ACTION_START
        }
        serviceController.withIntent(startIntent).startCommand(0, 1)

        // Advance the coroutine delay (MIC_HANDOFF_DELAY_MS = 1000ms) and then
        // allow the main-thread Handler callback (camera setup) to run.
        // runUiThreadTasksIncludingDelayedTasks() advances time and drains the main looper.
        org.robolectric.shadows.ShadowLooper.runUiThreadTasksIncludingDelayedTasks()

        // Assert 1: The concurrent overload MUST have been called
        // This assertion FAILS on unfixed code because the concurrent path is never taken.
        // Counterexample: bindToLifecycle(List<SingleCameraConfig>) was never called.
        try {
            verify(mockProvider).bindToLifecycle(any<List<SingleCameraConfig>>())
        } catch (e: AssertionError) {
            // Document the counterexample — this is the expected failure on unfixed code
            throw AssertionError(
                "BUG CONFIRMED (Requirement 1.2, 1.3): On a concurrent-capable device, " +
                "provider.bindToLifecycle(List<SingleCameraConfig>) was NEVER called. " +
                "The concurrent camera path is missing from VideoRecordingService. " +
                "Counterexample: isBugCondition(X) where X.appIsInForeground=true, " +
                "X.deviceSupportsConcurrentCameras=true, X.recordingEngine=SINGLE_CAMERA",
                e
            )
        }

        // Assert 2: The single-camera overload MUST NOT have been called
        // This assertion also FAILS on unfixed code because the single-camera overload IS called.
        // Counterexample: bindToLifecycle(LifecycleOwner, CameraSelector, VideoCapture) was called.
        try {
            verify(mockProvider, never()).bindToLifecycle(
                any<LifecycleOwner>(),
                any<CameraSelector>(),
                any<androidx.camera.core.UseCase>()
            )
        } catch (e: AssertionError) {
            throw AssertionError(
                "BUG CONFIRMED (Requirement 1.1, 1.3): On a concurrent-capable device, " +
                "provider.bindToLifecycle(LifecycleOwner, CameraSelector, VideoCapture) WAS called. " +
                "VideoRecordingService unconditionally uses the single-camera overload, " +
                "ignoring concurrent camera capability. " +
                "Counterexample: isBugCondition(X) where X.appIsInForeground=true, " +
                "X.deviceSupportsConcurrentCameras=true, X.recordingEngine=SINGLE_CAMERA",
                e
            )
        }
    }

    /**
     * Injects a mock ProcessCameraProvider so that ProcessCameraProvider.getInstance()
     * returns a future that resolves to the mock.
     *
     * Uses ProcessCameraProvider.configureInstance() — the official CameraX test injection
     * API. This does not require mockito-inline or camera-testing artifacts.
     */
    private fun injectMockCameraProvider(provider: ProcessCameraProvider) {
        ProcessCameraProvider.configureInstance(Futures.immediateFuture(provider))
    }
}
