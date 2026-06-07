package dev.paperscanner.paper_scanner_android

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.opencv.android.OpenCVLoader
import java.util.concurrent.Executors

/**
 * Android implementation of the `paper_scanner` plugin.
 *
 * Registers a [MethodChannel] named `paper_scanner` whose contract mirrors
 * `MethodChannelPaperScanner` on the Dart side. All heavy OpenCV work runs on a
 * single background executor; results are posted back on the main thread.
 */
class PaperScannerAndroidPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context

    /** Serializes native image work off the platform thread. */
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (!ensureOpenCv()) {
            result.error(ERR, "OpenCV failed to initialize", null)
            return
        }
        // Detach from the platform thread so the UI never blocks on OpenCV.
        worker.execute {
            try {
                val reply: Any? = when (call.method) {
                    "detectInImage" -> onDetectInImage(call)
                    "detectInFrame" -> onDetectInFrame(call)
                    "cropPerspective" -> onCropPerspective(call)
                    "applyFilter" -> onApplyFilter(call)
                    "rotate" -> onRotate(call)
                    else -> NOT_IMPLEMENTED
                }
                if (reply === NOT_IMPLEMENTED) {
                    main.post { result.notImplemented() }
                } else {
                    main.post { result.success(reply) }
                }
            } catch (t: Throwable) {
                main.post { result.error(ERR, t.message ?: t.toString(), null) }
            }
        }
    }

    // --- Handlers -----------------------------------------------------------

    private fun onDetectInImage(call: MethodCall): Map<String, Any>? {
        val path = call.argument<String>("path")!!
        val bitmap = ImageProcessor.loadUprightBitmap(path) ?: return null
        return DocumentDetector.detectInBitmap(bitmap)?.toReply()
    }

    private fun onDetectInFrame(call: MethodCall): Map<String, Any>? {
        val detected = DocumentDetector.detectInFrame(
            bytes = call.argument<ByteArray>("bytes")!!,
            width = call.argument<Int>("width")!!,
            height = call.argument<Int>("height")!!,
            bytesPerRow = call.argument<Int>("bytesPerRow")!!,
            rotation = call.argument<Int>("rotation") ?: 0,
            format = call.argument<String>("format") ?: "yuv420",
        )
        return detected?.toReply()
    }

    private fun onCropPerspective(call: MethodCall): String {
        val path = call.argument<String>("path")!!
        @Suppress("UNCHECKED_CAST")
        val corners = (call.argument<List<Any>>("corners")!!).map { (it as Number).toDouble() }
        return ImageProcessor.cropPerspective(appContext, path, corners)
    }

    private fun onApplyFilter(call: MethodCall): String {
        val path = call.argument<String>("path")!!
        val filter = call.argument<String>("filter") ?: "original"
        return ImageProcessor.applyFilter(appContext, path, filter)
    }

    private fun onRotate(call: MethodCall): String {
        val path = call.argument<String>("path")!!
        val quarterTurns = call.argument<Int>("quarterTurns") ?: 0
        return ImageProcessor.rotate(appContext, path, quarterTurns)
    }

    companion object {
        private const val CHANNEL = "paper_scanner"
        private const val ERR = "paper_scanner_error"
        private val NOT_IMPLEMENTED = Any()

        @Volatile
        private var openCvReady = false

        /** Lazily initializes the bundled OpenCV native libraries (idempotent). */
        @Synchronized
        private fun ensureOpenCv(): Boolean {
            if (!openCvReady) {
                openCvReady = OpenCVLoader.initLocal()
            }
            return openCvReady
        }
    }
}
