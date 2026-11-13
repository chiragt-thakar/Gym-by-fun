package app.motionquest.pose_bridge

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.SystemClock
import android.util.Rational
import android.util.Size
import android.view.Surface
import androidx.camera.core.CameraSelector
import androidx.camera.core.CameraState
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.UseCaseGroup
import androidx.camera.core.ViewPort
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LiveData
import androidx.lifecycle.Observer
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * CameraX front camera → MediaPipe Pose Landmarker (lite or full,
 * live-stream mode).
 *
 * Latest frame only (rule 3): CameraX keeps only the newest image, and while
 * the landmarker is busy any new frame is closed unprocessed — there is
 * never a queue. Pixels are released as soon as inference has read them.
 *
 * Self-view: when [selfView] is true a CameraX Preview is bound too. Its
 * frames go straight to a native PreviewView surface (GPU), never to Dart
 * and never to storage. Analysis and Preview share one 3:4 portrait
 * ViewPort, so landmark (0..1) coordinates line up with the preview.
 *
 * People: with [maxPoses] > 1 every detected body is sent (33 landmarks
 * each, one block after another); the Dart tracking engine locks onto the
 * player. Camera trouble (in use by another app, disabled, fatal) is
 * reported through [onError] with a "camera_error:<code>" message; CameraX
 * reopens the camera by itself when it can.
 */
internal class PosePipeline(
    private val context: Context,
    private val owner: LifecycleOwner,
    private val targetWidth: Int,
    private val targetHeight: Int,
    private val preferGpu: Boolean,
    private val fullModel: Boolean,
    private val selfView: Boolean,
    private val maxPoses: Int,
    private val minDetection: Float,
    private val minPresence: Float,
    private val minTracking: Float,
    private val onFrame: (DoubleArray) -> Unit,
    private val onError: (String) -> Unit,
) {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val busy = AtomicBoolean(false)
    private var landmarker: PoseLandmarker? = null
    private var provider: ProcessCameraProvider? = null
    private var delegateUsed = "cpu"
    private var lastTs = 0L
    @Volatile private var frameW = 0
    @Volatile private var frameH = 0
    @Volatile private var captureMs = 0L

    // The one upright bitmap handed to MediaPipe (busy == true while set).
    // Freed in onResult, or in analyze() if detectAsync never accepted it.
    @Volatile private var inFlight: Bitmap? = null

    // Set once by stop(); every async step checks it so a late callback never
    // binds the camera or touches a closed landmarker after stop.
    @Volatile private var stopped = false

    // Main thread only. Bound only when the player allows the self-view.
    private var preview: Preview? = null
    private var previewSurface: Preview.SurfaceProvider? = null
    @Volatile private var modelUsed = "lite"

    // Main thread only. Watches the camera for errors while it is bound.
    private var cameraState: LiveData<CameraState>? = null
    private var lastCameraError = -1
    private val cameraObserver = Observer<CameraState> { state ->
        val code = state.error?.code ?: -1
        if (code != lastCameraError) {
            lastCameraError = code
            if (code >= 0 && !stopped) onError("camera_error:$code")
        }
    }

    /**
     * Shows the preview on [surface] (a PreviewView), or stops feeding it
     * when null. Main thread. The analysis keeps running either way.
     */
    fun setPreviewSurface(surface: Preview.SurfaceProvider?) {
        previewSurface = surface
        preview?.setSurfaceProvider(surface)
    }

    /**
     * Starts model + camera. Exactly one of [onStarted] / [onFailed] is
     * called (the caller additionally guards against double answers).
     */
    fun start(onStarted: (Map<String, Any>) -> Unit, onFailed: (String) -> Unit) {
        try {
            executor.execute { startOnExecutor(onStarted, onFailed) }
        } catch (e: Exception) {
            onFailed("Pose pipeline not available: ${e.message}")
        }
    }

    private fun startOnExecutor(onStarted: (Map<String, Any>) -> Unit, onFailed: (String) -> Unit) {
        if (stopped) {
            onFailed("Pose pipeline stopped")
            return
        }
        try {
            landmarker = createLandmarker(preferGpu)
        } catch (e: Exception) {
            onFailed("Pose model failed to load: ${e.message}")
            return
        }
        try {
            val future = ProcessCameraProvider.getInstance(context)
            future.addListener({
                try {
                    if (stopped) {
                        onFailed("Pose pipeline stopped")
                        return@addListener
                    }
                    val p = future.get()
                    provider = p
                    // 4:3 sensor output = 3:4 portrait, the full field of view.
                    val ratio43 = AspectRatioStrategy.RATIO_4_3_FALLBACK_AUTO_STRATEGY
                    val analysis = ImageAnalysis.Builder()
                        .setResolutionSelector(
                            ResolutionSelector.Builder()
                                .setAspectRatioStrategy(ratio43)
                                .setResolutionStrategy(
                                    ResolutionStrategy(
                                        Size(targetHeight, targetWidth),
                                        ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER,
                                    ),
                                )
                                .build(),
                        )
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                        .build()
                    analysis.setAnalyzer(executor, ::analyze)
                    val group = UseCaseGroup.Builder()
                        .setViewPort(ViewPort.Builder(Rational(3, 4), Surface.ROTATION_0).build())
                        .addUseCase(analysis)
                    if (selfView) {
                        // Small preview: it is only a mirror for framing.
                        val pv = Preview.Builder()
                            .setResolutionSelector(
                                ResolutionSelector.Builder()
                                    .setAspectRatioStrategy(ratio43)
                                    .setResolutionStrategy(
                                        ResolutionStrategy(
                                            Size(640, 480),
                                            ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                                        ),
                                    )
                                    .build(),
                            )
                            .build()
                        pv.setSurfaceProvider(previewSurface)
                        preview = pv
                        group.addUseCase(pv)
                    }
                    p.unbindAll()
                    val camera =
                        p.bindToLifecycle(owner, CameraSelector.DEFAULT_FRONT_CAMERA, group.build())
                    val state = camera.cameraInfo.cameraState
                    state.observe(owner, cameraObserver)
                    cameraState = state
                    onStarted(
                        mapOf(
                            "delegate" to delegateUsed,
                            "model" to modelUsed,
                            "selfView" to selfView,
                        ),
                    )
                } catch (e: Exception) {
                    onFailed("Camera failed to start: ${e.message}")
                }
            }, ContextCompat.getMainExecutor(context))
        } catch (e: Exception) {
            onFailed("Camera failed to start: ${e.message}")
        }
    }

    private fun createLandmarker(gpu: Boolean): PoseLandmarker {
        fun build(delegate: Delegate, model: String): PoseLandmarker {
            val base = BaseOptions.builder()
                .setModelAssetPath("pose_landmarker_$model.task")
                .setDelegate(delegate)
                .build()
            val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(base)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setNumPoses(maxPoses)
                .setMinPoseDetectionConfidence(minDetection)
                .setMinPosePresenceConfidence(minPresence)
                .setMinTrackingConfidence(minTracking)
                .setResultListener(::onResult)
                .setErrorListener { e -> onError(e.message ?: "pose error") }
                .build()
            return PoseLandmarker.createFromOptions(context, options)
        }
        // Full is only tried on fast phones and only on the GPU; any failure
        // falls back to Lite, then to the CPU.
        val models = if (fullModel) listOf("full", "lite") else listOf("lite")
        if (gpu) {
            for (model in models) {
                try {
                    return build(Delegate.GPU, model).also {
                        delegateUsed = "gpu"
                        modelUsed = model
                    }
                } catch (_: Exception) {
                    // Some budget GPUs can't run the model: try the next one.
                }
            }
        }
        return build(Delegate.CPU, "lite").also {
            delegateUsed = "cpu"
            modelUsed = "lite"
        }
    }

    private fun analyze(image: ImageProxy) {
        val lm = landmarker
        if (stopped || lm == null || !busy.compareAndSet(false, true)) {
            image.close() // drop: inference still busy with the previous frame
            return
        }
        var upright: Bitmap? = null
        try {
            val rotation = image.imageInfo.rotationDegrees
            // The shared ViewPort's crop (usually the whole 4:3 frame), so
            // landmarks are normalised to exactly what the preview shows.
            val crop = image.cropRect
            val raw = image.toBitmap()
            image.close()
            // Upright + mirrored, so landmarks read like a selfie: the
            // player's left is smaller x.
            val m = Matrix().apply {
                postRotate(rotation.toFloat())
                postScale(-1f, 1f)
            }
            val cx = crop.left.coerceIn(0, raw.width - 1)
            val cy = crop.top.coerceIn(0, raw.height - 1)
            val cw = crop.width().coerceIn(1, raw.width - cx)
            val ch = crop.height().coerceIn(1, raw.height - cy)
            val rotated = Bitmap.createBitmap(raw, cx, cy, cw, ch, m, true)
            if (rotated !== raw) raw.recycle()
            upright = rotated
            frameW = rotated.width
            frameH = rotated.height
            var ts = SystemClock.uptimeMillis()
            if (ts <= lastTs) ts = lastTs + 1
            lastTs = ts
            captureMs = ts
            inFlight = rotated
            lm.detectAsync(BitmapImageBuilder(rotated).build(), ts)
        } catch (e: Exception) {
            inFlight = null
            upright?.let { if (!it.isRecycled) it.recycle() }
            busy.set(false)
            image.close()
            onError("Frame failed: ${e.message}")
        }
    }

    private fun onResult(result: PoseLandmarkerResult, input: com.google.mediapipe.framework.image.MPImage) {
        val inference = (SystemClock.uptimeMillis() - captureMs).toDouble()
        val w = frameW
        val h = frameH
        // Release pixels before accepting the next frame, so at most one
        // upright bitmap exists at a time (budget phones have little RAM).
        input.close()
        inFlight?.let { if (!it.isRecycled) it.recycle() }
        inFlight = null
        busy.set(false)
        if (stopped) return
        val ts = result.timestampMs()
        val poses = result.landmarks()
        // Header + one 33-landmark block per body. A body with an unexpected
        // landmark count is skipped so the blocks always line up.
        val bodies = poses.filter { it.size == LANDMARKS }
        val out = DoubleArray(4 + bodies.size * LANDMARKS * 4)
        out[0] = ts.toDouble()
        out[1] = w.toDouble()
        out[2] = h.toDouble()
        out[3] = inference
        var o = 4
        for (pose in bodies) {
            for (p in pose) {
                out[o] = p.x().toDouble()
                out[o + 1] = p.y().toDouble()
                out[o + 2] = p.z().toDouble()
                out[o + 3] = p.visibility().orElse(0f).toDouble()
                o += 4
            }
        }
        onFrame(out)
    }

    fun stop() {
        if (stopped) return
        stopped = true
        try {
            ContextCompat.getMainExecutor(context).execute {
                cameraState?.removeObserver(cameraObserver)
                cameraState = null
                preview?.setSurfaceProvider(null)
                preview = null
                provider?.unbindAll()
            }
        } catch (_: Exception) {
        }
        try {
            executor.execute {
                landmarker?.close()
                landmarker = null
                inFlight?.let { if (!it.isRecycled) it.recycle() }
                inFlight = null
            }
        } catch (_: Exception) {
        }
        executor.shutdown()
    }

    private companion object {
        const val LANDMARKS = 33
    }
}
