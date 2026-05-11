package com.nexus.sheildai.sheild_ai.dualcamera

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * DualCameraViewFactory — Registered with FlutterEngine to instantiate [DualCameraView].
 *
 * Registered under [DualCameraConstants.VIEW_TYPE_ID].
 * Flutter instantiates one [DualCameraView] per `AndroidView` widget in the Dart tree.
 *
 * @param messenger The [BinaryMessenger] from the FlutterEngine, passed down to
 *                  [DualCameraView] so it can set up its own MethodChannel / EventChannel.
 */
class DualCameraViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return DualCameraView(
            context  = context,
            messenger = messenger,
            viewId   = viewId,
        )
    }
}
