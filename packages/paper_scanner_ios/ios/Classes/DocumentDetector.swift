import CoreGraphics
import Foundation
import Vision

/// A detected quad in normalized (0..1, top-left origin) coordinates.
struct DetectionResult {
  /// Flattened corners: [tlX, tlY, trX, trY, brX, brY, blX, blY].
  let corners: [Double]
  let confidence: Double

  func toReply() -> [String: Any] {
    return ["corners": corners, "confidence": confidence]
  }
}

/// Document detection via Apple Vision.
///
/// Prefers `VNDetectDocumentSegmentationRequest` (iOS 15+) and falls back to
/// `VNDetectRectanglesRequest` on older systems. VisionKit's full-UI document
/// camera is deliberately avoided because it renders its own non-customizable
/// interface; these requests are detection-only.
enum DocumentDetector {

  static func detect(
    in cgImage: CGImage,
    orientation: CGImagePropertyOrientation
  ) -> DetectionResult? {
    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

    if #available(iOS 15.0, *) {
      let request = VNDetectDocumentSegmentationRequest()
      if (try? handler.perform([request])) != nil,
         let observation = request.results?.first {
        return map(observation)
      }
    }

    // Fallback for older iOS or when segmentation finds nothing.
    let rectangles = VNDetectRectanglesRequest()
    rectangles.maximumObservations = 1
    rectangles.minimumConfidence = 0.4
    rectangles.minimumAspectRatio = 0.3
    rectangles.maximumAspectRatio = 1.0
    rectangles.minimumSize = 0.2
    rectangles.quadratureTolerance = 30
    if (try? handler.perform([rectangles])) != nil,
       let observation = rectangles.results?.first {
      return map(observation)
    }
    return nil
  }

  /// Vision reports normalized corners with a bottom-left origin; flip `y` to
  /// the top-left origin used across the plugin and reorder to TL,TR,BR,BL.
  private static func map(_ observation: VNRectangleObservation) -> DetectionResult {
    func conv(_ p: CGPoint) -> [Double] { [Double(p.x), Double(1 - p.y)] }
    let corners =
      conv(observation.topLeft) +
      conv(observation.topRight) +
      conv(observation.bottomRight) +
      conv(observation.bottomLeft)
    return DetectionResult(corners: corners, confidence: Double(observation.confidence))
  }

  /// Builds a `CGImage` from a raw preview buffer streamed from the camera.
  ///
  /// `bgra8888` is the default iOS camera stream format; `yuv420` is handled as
  /// a luminance-only grayscale image (sufficient for edge detection).
  static func cgImage(
    from data: Data,
    width: Int,
    height: Int,
    bytesPerRow: Int,
    format: String
  ) -> CGImage? {
    guard let provider = CGDataProvider(data: data as CFData) else { return nil }

    if format == "yuv420" {
      return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      )
    }

    // BGRA, little-endian 32-bit.
    let bitmapInfo = CGBitmapInfo(
      rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
        | CGBitmapInfo.byteOrder32Little.rawValue
    )
    return CGImage(
      width: width,
      height: height,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: bytesPerRow,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: .defaultIntent
    )
  }

  /// Maps a clockwise [rotation] in degrees to a `CGImagePropertyOrientation`.
  static func orientation(forRotation rotation: Int) -> CGImagePropertyOrientation {
    switch ((rotation % 360) + 360) % 360 {
    case 90: return .right
    case 180: return .down
    case 270: return .left
    default: return .up
    }
  }
}
