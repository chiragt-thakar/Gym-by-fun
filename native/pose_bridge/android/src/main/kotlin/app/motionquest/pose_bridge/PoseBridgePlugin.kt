package app.motionquest.pose_bridge

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.util.concurrent.atomic.AtomicBoolean

/**
 * MotionQuest pose bridge.
 *
 * Camera frames never leave native code (rule 4) and are never stored
 * (rule 2). Only 33 landmarks + visibility + timestamp cross into Dart, as a
 * flat DoubleArray: [t, w, h, inferenceMs, x0, y0, z0, v0, x1, ...].
 *
 * Methods: hasPermission, requestPermission,
 * start {width, height, delegate, model, selfView}, stop.
 * Event channel: landmark frames. Platform view "motionquest/self_view": the
 * optional camera mirror (native surface; FLAG_SECURE while it is shown).
 */
class PoseBridgePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var sink: EventChannel.EventSink? = null
    private var pipeline: PosePipeline? = null
    private var pendingPermission: MethodChannel.Result? = null
    private val main = Handler(Looper.getMainLooper())

    // Self-view mirrors currently on screen (main thread). The newest one
    // receives the preview.
    private val shownViews = mutableListOf<PreviewView>()

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        methods = MethodChannel(b.binaryMessenger, "motionquest/pose_bridge")
        methods.setMethodCallHandler(this)
        events = EventChannel(b.binaryMessenger, "motionquest/pose_bridge/landmarks")
        events.setStreamHandler(this)
        b.platformViewRegistry.registerViewFactory(
            SELF_VIEW_TYPE,
            SelfViewFactory(onShown = ::showSelfView, onHidden = ::hideSelfView),
        )
    }

    private fun showSelfView(v: PreviewView) {
        shownViews.remove(v)
        shownViews.add(v)
        pipeline?.setPreviewSurface(v.surfaceProvider)
        updateSecure()
    }

    private fun hideSelfView(v: PreviewView) {
        shownViews.remove(v)
        pipeline?.setPreviewSurface(shownViews.lastOrNull()?.surfaceProvider)
        updateSecure()
    }

    /** No screenshots or recents thumbnails while a camera image is shown. */
    private fun updateSecure() {
        val w = activity?.window ?: return
        if (shownViews.isNotEmpty()) {
            w.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            w.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        stopPipeline()
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasPermission())
            "requestPermission" -> requestPermission(result)
            "start" -> start(call, result)
            "stop" -> {
                stopPipeline()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasPermission(): Boolean {
        val a = activity ?: return false
        return ContextCompat.checkSelfPermission(a, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestPermission(result: MethodChannel.Result) {
        val a = activity ?: return result.error("no_activity", "Not attached", null)
        if (hasPermission()) return result.success(true)
        if (pendingPermission != null) {
            return result.error("in_progress", "A permission request is already pending", null)
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(a, arrayOf(Manifest.permission.CAMERA), REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE) return false
        pendingPermission?.success(
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED,
        )
        pendingPermission = null
        return true
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        val a = activity ?: return result.error("no_activity", "Not attached", null)
        val owner = a as? LifecycleOwner
            ?: return result.error("no_lifecycle", "Activity is not a LifecycleOwner", null)
        if (!hasPermission()) return result.error("no_permission", "Camera permission missing", null)
        stopPipeline()
        val width = call.argument<Int>("width") ?: 480
        val height = call.argument<Int>("height") ?: 640
        val preferGpu = (call.argument<String>("delegate") ?: "gpu") == "gpu"
        val fullModel = call.argument<String>("model") == "full"
        val selfView = call.argument<Boolean>("selfView") ?: false
        val p = PosePipeline(
            context = a.applicationContext,
            owner = owner,
            targetWidth = width,
            targetHeight = height,
            preferGpu = preferGpu,
            fullModel = fullModel,
            selfView = selfView,
            onFrame = { frame -> main.post { sink?.success(frame) } },
            onError = { msg -> main.post { sink?.error("pose_error", msg, null) } },
        )
        pipeline = p
        // A mirror already on screen gets the preview as soon as it binds.
        p.setPreviewSurface(shownViews.lastOrNull()?.surfaceProvider)
        // The Dart future must be answered exactly once, success or error.
        val answered = AtomicBoolean(false)
        p.start(
            onStarted = { info ->
                if (answered.compareAndSet(false, true)) main.post { result.success(info) }
            },
            onFailed = { msg ->
                if (answered.compareAndSet(false, true)) {
                    main.post { result.error("start_failed", msg, null) }
                }
            },
        )
    }

    private fun stopPipeline() {
        pipeline?.stop()
        pipeline = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        activity = b.activity
        binding = b
        b.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) =
        onAttachedToActivity(b)

    override fun onDetachedFromActivity() {
        stopPipeline()
        activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        pendingPermission?.success(false)
        pendingPermission = null
        binding?.removeRequestPermissionsResultListener(this)
        binding = null
        activity = null
    }

    private companion object {
        const val REQUEST_CODE = 4317
        const val SELF_VIEW_TYPE = "motionquest/self_view"
    }
}
