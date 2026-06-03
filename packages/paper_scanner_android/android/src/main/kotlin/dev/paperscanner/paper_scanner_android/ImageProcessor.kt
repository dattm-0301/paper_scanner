package dev.paperscanner.paper_scanner_android

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import org.opencv.android.Utils
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.MatOfPoint2f
import org.opencv.core.Point
import org.opencv.core.Size
import org.opencv.imgproc.CLAHE
import org.opencv.imgproc.Imgproc
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import kotlin.math.hypot
import kotlin.math.max

/** Perspective crop and filter operations, all Bitmap-in / file-out. */
object ImageProcessor {

    private const val JPEG_QUALITY = 92

    /**
     * Decodes [path] and rotates it upright according to its EXIF orientation,
     * so detection and crop operate on the same pixels Flutter shows via
     * `Image.file` (which also honors EXIF).
     */
    fun loadUprightBitmap(path: String): Bitmap? {
        val decoded = BitmapFactory.decodeFile(path) ?: return null
        val orientation = try {
            ExifInterface(path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        } catch (_: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
            else -> return decoded
        }
        return Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
    }

    /** Warps the four normalized [corners] (TL,TR,BR,BL) to a flat rectangle. */
    fun cropPerspective(context: Context, path: String, corners: List<Double>): String {
        val bitmap = loadUprightBitmap(path)
            ?: throw IllegalArgumentException("Unable to decode image at $path")
        val src = Mat()
        Utils.bitmapToMat(bitmap, src) // RGBA
        val w = src.cols().toDouble()
        val h = src.rows().toDouble()

        val tl = Point(corners[0] * w, corners[1] * h)
        val tr = Point(corners[2] * w, corners[3] * h)
        val br = Point(corners[4] * w, corners[5] * h)
        val bl = Point(corners[6] * w, corners[7] * h)

        val widthTop = hypot(tr.x - tl.x, tr.y - tl.y)
        val widthBottom = hypot(br.x - bl.x, br.y - bl.y)
        val heightLeft = hypot(bl.x - tl.x, bl.y - tl.y)
        val heightRight = hypot(br.x - tr.x, br.y - tr.y)
        val outW = max(widthTop, widthBottom).coerceAtLeast(1.0)
        val outH = max(heightLeft, heightRight).coerceAtLeast(1.0)

        val srcQuad = MatOfPoint2f(tl, tr, br, bl)
        val dstQuad = MatOfPoint2f(
            Point(0.0, 0.0),
            Point(outW - 1, 0.0),
            Point(outW - 1, outH - 1),
            Point(0.0, outH - 1),
        )
        val transform = Imgproc.getPerspectiveTransform(srcQuad, dstQuad)
        val out = Mat()
        Imgproc.warpPerspective(src, out, transform, Size(outW, outH))

        src.release()
        srcQuad.release()
        dstQuad.release()
        transform.release()

        return matToJpeg(context, out)
    }

    /** Applies [filter] (`enhance` / `grayscale` / `blackWhite`) to [path]. */
    fun applyFilter(context: Context, path: String, filter: String): String {
        val bitmap = loadUprightBitmap(path)
            ?: throw IllegalArgumentException("Unable to decode image at $path")
        val rgba = Mat()
        Utils.bitmapToMat(bitmap, rgba)

        val result = Mat()
        when (filter) {
            "grayscale" -> {
                val gray = Mat()
                Imgproc.cvtColor(rgba, gray, Imgproc.COLOR_RGBA2GRAY)
                Imgproc.cvtColor(gray, result, Imgproc.COLOR_GRAY2RGBA)
                gray.release()
            }
            "blackWhite" -> {
                val gray = Mat()
                Imgproc.cvtColor(rgba, gray, Imgproc.COLOR_RGBA2GRAY)
                val bw = Mat()
                Imgproc.adaptiveThreshold(
                    gray, bw, 255.0,
                    Imgproc.ADAPTIVE_THRESH_GAUSSIAN_C, Imgproc.THRESH_BINARY,
                    15, 10.0,
                )
                Imgproc.cvtColor(bw, result, Imgproc.COLOR_GRAY2RGBA)
                gray.release()
                bw.release()
            }
            "enhance" -> enhance(rgba, result)
            else -> rgba.copyTo(result) // "original" or unknown
        }
        rgba.release()
        return matToJpeg(context, result)
    }

    /** CLAHE on the L channel (Lab) plus a mild contrast bump. */
    private fun enhance(rgba: Mat, out: Mat) {
        val rgb = Mat()
        Imgproc.cvtColor(rgba, rgb, Imgproc.COLOR_RGBA2RGB)
        val lab = Mat()
        Imgproc.cvtColor(rgb, lab, Imgproc.COLOR_RGB2Lab)
        val channels = ArrayList<Mat>()
        Core.split(lab, channels)
        val clahe: CLAHE = Imgproc.createCLAHE(2.0, Size(8.0, 8.0))
        clahe.apply(channels[0], channels[0])
        Core.merge(channels, lab)
        val enhancedRgb = Mat()
        Imgproc.cvtColor(lab, enhancedRgb, Imgproc.COLOR_Lab2RGB)
        // Slight global contrast/brightness lift.
        enhancedRgb.convertTo(enhancedRgb, -1, 1.08, 4.0)
        Imgproc.cvtColor(enhancedRgb, out, Imgproc.COLOR_RGB2RGBA)

        rgb.release()
        lab.release()
        enhancedRgb.release()
        channels.forEach { it.release() }
    }

    /** Renders an RGBA [mat] to a JPEG in the app cache and returns its path. */
    private fun matToJpeg(context: Context, mat: Mat): String {
        val bitmap = Bitmap.createBitmap(mat.cols(), mat.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(mat, bitmap)
        mat.release()

        val dir = File(context.cacheDir, "paper_scanner").apply { mkdirs() }
        val file = File(dir, "${UUID.randomUUID()}.jpg")
        FileOutputStream(file).use { os ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, os)
        }
        bitmap.recycle()
        return file.absolutePath
    }
}
