package app.motionquest.pose_bridge

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.SystemClock
import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
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
 * CameraX front camera → MediaPipe Pose Landmarker (lite, live-stream mode).
 *
 * Latest frame only (rule 3): CameraX keeps only the newest image, and while
 * the landmarker is busy any new frame is closed unprocessed — there is
 * never a queue. Pixels are released as soon as inference has read them.
 */
internal class PosePipeline(
    private val context: Context,
    private val owner: LifecycleOwner,
    private val targetWidth: Int,
    private val targetHeight: Int,
    private val preferGpu: Boolean,
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

    fun start(onStarted: (Map<String, Any>) -> Unit) {
        executor.execute {
            try {
                landmarker = createLandmarker(preferGpu)
            } catch (e: Exception) {
                onError("Pose model failed to load: ${e.message}")
                return@execute
            }
            val future = ProcessCameraProvider.getInstance(context)
            future.addListener({
                try {
                    val p = future.get()
                    provider = p
                    val analysis = ImageAnalysis.Builder()
                        .setResolutionSelector(
                            ResolutionSelector.Builder()
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
                    p.unbindAll()
                    p.bindToLifecycle(owner, CameraSelector.DEFAULT_FRONT_CAMERA, analysis)
                    onStarted(mapOf("delegate" to delegateUsed))
                } catch (e: Exception) {
                    onError("Camera failed to start: ${e.message}")
                }
            }, ContextCompat.getMainExecutor(context))
        }
    }

    private fun createLandmarker(gpu: Boolean): PoseLandmarker {
        fun build(delegate: Delegate): PoseLandmarker {
            val base = BaseOptions.builder()
                .setModelAssetPath(MODEL_ASSET)
                .setDelegate(delegate)
                .build()
            val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(base)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setNumPoses(1)
                .setMinPoseDetectionConfidence(0.5f)
                .setMinPosePresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setResultListener(::onResult)
                .setErrorListener { e -> onError(e.message ?: "pose error") }
                .build()
            return PoseLandmarker.createFromOptions(context, options)
        }
        if (gpu) {
            try {
                return build(Delegate.GPU).also { delegateUsed = "gpu" }
            } catch (_: Exception) {
                // Some budget GPUs can't run the model: fall back to CPU.
            }
        }
        return build(Delegate.CPU).also { delegateUsed = "cpu" }
    }

    private fun analyze(image: ImageProxy) {
        val lm = landmarker
        if (lm == null || !busy.compareAndSet(false, true)) {
            image.close() // drop: inference still busy with the previous frame
            return
        }
        try {
            val rotation = image.imageInfo.rotationDegrees
            val raw = image.toBitmap()
            image.close()
            // Upright + mirrored, so landmarks read like a selfie: the
            // player's left is smaller x.
            val m = Matrix().apply {
                postRotate(rotation.toFloat())
                postScale(-1f, 1f)
            }
            val upright = Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, m, true)
            if (upright !== raw) raw.recycle()
            frameW = upright.width
            frameH = upright.height
            var ts = SystemClock.uptimeMillis()
            if (ts <= lastTs) ts = lastTs + 1
            lastTs = ts
            captureMs = ts
            lm.detectAsync(BitmapImageBuilder(upright).build(), ts)
        } catch (e: Exception) {
            busy.set(false)
            image.close()
            onError("Frame failed: ${e.message}")
        }
    }

    private fun onResult(result: PoseLandmarkerResult, input: com.google.mediapipe.framework.image.MPImage) {
        busy.set(false)
        input.close()
        val ts = result.timestampMs()
        val inference = (SystemClock.uptimeMillis() - captureMs).toDouble()
        val poses = result.landmarks()
        val out: DoubleArray
        if (poses.isEmpty()) {
            out = doubleArrayOf(ts.toDouble(), frameW.toDouble(), frameH.toDouble(), inference)
        } else {
            val pose = poses[0]
            out = DoubleArray(4 + pose.size * 4)
            out[0] = ts.toDouble()
            out[1] = frameW.toDouble()
            out[2] = frameH.toDouble()
            out[3] = inference
            for ((i, p) in pose.withIndex()) {
                val o = 4 + i * 4
                out[o] = p.x().toDouble()
                out[o + 1] = p.y().toDouble()
                out[o + 2] = p.z().toDouble()
                out[o + 3] = p.visibility().orElse(0f).toDouble()
            }
        }
        onFrame(out)
    }

    fun stop() {
        try {
            ContextCompat.getMainExecutor(context).execute { provider?.unbindAll() }
        } catch (_: Exception) {
        }
        executor.execute {
            landmarker?.close()
            landmarker = null
        }
        executor.shutdown()
    }

    private companion object {
        const val MODEL_ASSET = "pose_landmarker_lite.task"
    }
}
