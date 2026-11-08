package app.motionquest.pose_bridge

import android.content.Context
import android.view.View
import androidx.camera.view.PreviewView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * The self-view mirror: a CameraX PreviewView shown inside Flutter as a
 * platform view. The camera image goes from the camera straight to this
 * view's surface on the GPU. Dart never receives a pixel (rule 4), and
 * nothing is stored (rule 2).
 *
 * PreviewView handles sensor rotation, the ViewPort crop and front-camera
 * mirroring on every device, so the picture matches the selfie-space
 * landmarks drawn on top of it in Dart.
 */
internal class SelfViewFactory(
    private val onShown: (PreviewView) -> Unit,
    private val onHidden: (PreviewView) -> Unit,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        SelfView(context, onShown, onHidden)
}

private class SelfView(
    context: Context,
    private val onShown: (PreviewView) -> Unit,
    private val onHidden: (PreviewView) -> Unit,
) : PlatformView {
    private val view = PreviewView(context).apply {
        // TextureView: composes correctly inside Flutter's platform views.
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        // The Dart widget is sized to the 3:4 viewport, so this fills it.
        scaleType = PreviewView.ScaleType.FIT_CENTER
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
    }

    init {
        onShown(view)
    }

    override fun getView(): View = view

    override fun dispose() {
        onHidden(view)
    }
}
