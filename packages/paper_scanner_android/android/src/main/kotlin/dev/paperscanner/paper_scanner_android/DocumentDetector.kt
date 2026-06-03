package dev.paperscanner.paper_scanner_android

import android.graphics.Bitmap
import org.opencv.android.Utils
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.MatOfPoint
import org.opencv.core.MatOfPoint2f
import org.opencv.core.Point
import org.opencv.core.Size
import org.opencv.imgproc.Imgproc
import kotlin.math.max

/** A detected quad expressed in normalized (0..1, top-left origin) coordinates. */
data class DetectionResult(
    /** Flattened corners: [tlX, tlY, trX, trY, brX, brY, blX, blY]. */
    val corners: List<Double>,
    val confidence: Double,
) {
    fun toReply(): Map<String, Any> = mapOf("corners" to corners, "confidence" to confidence)
}

/**
 * Document-quad detection via classic OpenCV edge finding:
 * `gray → blur → Canny → findContours → approxPolyDP → largest convex 4-gon`.
 *
 * There is no public standalone ML Kit document-quad detector (it is locked
 * inside the full-UI `GmsDocumentScanner`), which is why this uses OpenCV.
 */
object DocumentDetector {

    private const val WORK_DIM = 600.0 // longest edge used for detection
    private const val MIN_AREA_RATIO = 0.18 // reject tiny contours

    /** Detects the document outline in an upright [bitmap]. */
    fun detectInBitmap(bitmap: Bitmap): DetectionResult? {
        val rgba = Mat()
        Utils.bitmapToMat(bitmap, rgba)
        val gray = Mat()
        Imgproc.cvtColor(rgba, gray, Imgproc.COLOR_RGBA2GRAY)
        rgba.release()
        return try {
            detect(gray)
        } finally {
            gray.release()
        }
    }

    /**
     * Detects the document outline in a single preview frame.
     *
     * For [format] `yuv420` only the Y (luminance) plane is supplied — exactly
     * what edge detection needs — with [bytesPerRow] carrying any stride
     * padding. For `bgra8888` the interleaved buffer is converted to gray.
     * [rotation] (0/90/180/270, clockwise) is applied so corners come back in
     * the upright space the preview is displayed in.
     */
    fun detectInFrame(
        bytes: ByteArray,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        rotation: Int,
        format: String,
    ): DetectionResult? {
        var gray = Mat()
        try {
            if (format == "bgra8888") {
                val pixelStride = if (bytesPerRow > 0) bytesPerRow / 4 else width
                val bgra = Mat(height, pixelStride, CvType.CV_8UC4)
                bgra.put(0, 0, bytes)
                val cropped = bgra.submat(0, height, 0, width)
                Imgproc.cvtColor(cropped, gray, Imgproc.COLOR_BGRA2GRAY)
                bgra.release()
            } else {
                val stride = if (bytesPerRow > 0) bytesPerRow else width
                val full = Mat(height, stride, CvType.CV_8UC1)
                full.put(0, 0, bytes)
                // Strip row padding so the Mat is exactly width x height.
                gray = full.submat(0, height, 0, width).clone()
                full.release()
            }
            gray = rotate(gray, rotation)
            return detect(gray)
        } finally {
            gray.release()
        }
    }

    // --- core pipeline ------------------------------------------------------

    private fun detect(gray: Mat): DetectionResult? {
        val fullW = gray.cols().toDouble()
        val fullH = gray.rows().toDouble()
        if (fullW < 2 || fullH < 2) return null

        val scale = WORK_DIM / max(fullW, fullH)
        val small = Mat()
        if (scale < 1.0) {
            Imgproc.resize(gray, small, Size(), scale, scale, Imgproc.INTER_AREA)
        } else {
            gray.copyTo(small)
        }

        Imgproc.GaussianBlur(small, small, Size(5.0, 5.0), 0.0)
        val edges = Mat()
        Imgproc.Canny(small, edges, 75.0, 200.0)
        // Close small gaps so document borders form a single contour.
        Imgproc.dilate(edges, edges, Mat(), Point(-1.0, -1.0), 1)

        val contours = ArrayList<MatOfPoint>()
        Imgproc.findContours(
            edges, contours, Mat(),
            Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_SIMPLE,
        )
        small.release()
        edges.release()

        val workArea = (WORK_DIM * WORK_DIM)
        contours.sortByDescending { Imgproc.contourArea(it) }

        val effScale = if (scale < 1.0) scale else 1.0
        try {
            for (contour in contours.take(8)) {
                val c2f = MatOfPoint2f(*contour.toArray())
                val peri = Imgproc.arcLength(c2f, true)
                val approx = MatOfPoint2f()
                Imgproc.approxPolyDP(c2f, approx, 0.02 * peri, true)
                c2f.release()

                if (approx.total() == 4L) {
                    val approxPts = MatOfPoint(*approx.toArray())
                    val area = Imgproc.contourArea(approx)
                    val convex = Imgproc.isContourConvex(approxPts)
                    approxPts.release()
                    if (convex && area >= MIN_AREA_RATIO * workArea) {
                        // Map detection-space points back to full resolution.
                        val pts = approx.toArray().map { Point(it.x / effScale, it.y / effScale) }
                        val ordered = orderCorners(pts)
                        approx.release()
                        val confidence = (area / workArea).coerceIn(0.0, 1.0)
                        return DetectionResult(
                            corners = listOf(
                                ordered[0].x / fullW, ordered[0].y / fullH,
                                ordered[1].x / fullW, ordered[1].y / fullH,
                                ordered[2].x / fullW, ordered[2].y / fullH,
                                ordered[3].x / fullW, ordered[3].y / fullH,
                            ),
                            confidence = confidence,
                        )
                    }
                }
                approx.release()
            }
        } finally {
            contours.forEach { it.release() }
        }
        return null
    }

    /** Orders four points as TL, TR, BR, BL using sum/diff heuristics. */
    private fun orderCorners(pts: List<Point>): List<Point> {
        val tl = pts.minByOrNull { it.x + it.y }!!
        val br = pts.maxByOrNull { it.x + it.y }!!
        val tr = pts.minByOrNull { it.y - it.x }!!
        val bl = pts.maxByOrNull { it.y - it.x }!!
        return listOf(tl, tr, br, bl)
    }

    private fun rotate(src: Mat, rotation: Int): Mat {
        val code = when (((rotation % 360) + 360) % 360) {
            90 -> Core.ROTATE_90_CLOCKWISE
            180 -> Core.ROTATE_180
            270 -> Core.ROTATE_90_COUNTERCLOCKWISE
            else -> return src
        }
        val out = Mat()
        Core.rotate(src, out, code)
        src.release()
        return out
    }
}
