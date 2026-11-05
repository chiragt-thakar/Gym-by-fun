package app.motionquest.pose_bridge

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
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

/**
 * MotionQuest pose bridge.
 *
 * Camera frames never leave native code (rule 4) and are never stored
 * (rule 2). Only 33 landmarks + visibility + timestamp cross into Dart, as a
 * flat DoubleArray: [t, w, h, inferenceMs, x0, y0, z0, v0, x1, ...].
 *
 * Methods: hasPermission, requestPermission, start {width, height, delegate},
 * stop. Event channel: landmark frames.
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

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        methods = MethodChannel(b.binaryMessenger, "motionquest/pose_bridge")
        methods.setMethodCallHandler(this)
        events = EventChannel(b.binaryMessenger, "motionquest/pose_bridge/landmarks")
        events.setStreamHandler(this)
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
        val p = PosePipeline(
            context = a.applicationContext,
            owner = owner,
            targetWidth = width,
            targetHeight = height,
            preferGpu = preferGpu,
            onFrame = { frame -> main.post { sink?.success(frame) } },
            onError = { msg -> main.post { sink?.error("pose_error", msg, null) } },
        )
        pipeline = p
        p.start { info -> main.post { result.success(info) } }
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
        binding?.removeRequestPermissionsResultListener(this)
        binding = null
        activity = null
    }

    private companion object {
        const val REQUEST_CODE = 4317
    }
}
