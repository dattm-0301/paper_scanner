import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

/// Perspective crop and filters via CoreImage, plus EXIF-aware decoding.
enum ImageProcessor {

  enum ProcessingError: Error { case decode, render }

  /// Shared rendering context (expensive to create — reuse it).
  private static let context = CIContext(options: nil)
  private static let jpegQuality: CGFloat = 0.92

  /// Decodes [path] and bakes its orientation into the pixels so detection and
  /// crop share the same upright geometry Flutter shows via `Image.file`.
  static func uprightCGImage(path: String) -> CGImage? {
    guard let image = UIImage(contentsOfFile: path) else { return nil }
    return normalizedUp(image).cgImage
  }

  private static func normalizedUp(_ image: UIImage) -> UIImage {
    if image.imageOrientation == .up { return image }
    UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
    image.draw(in: CGRect(origin: .zero, size: image.size))
    let normalized = UIGraphicsGetImageFromCurrentImageContext() ?? image
    UIGraphicsEndImageContext()
    return normalized
  }

  /// Warps the four normalized [corners] (TL,TR,BR,BL) to a flat rectangle.
  static func cropPerspective(path: String, corners: [Double]) throws -> String {
    guard let cg = uprightCGImage(path: path) else { throw ProcessingError.decode }
    let ci = CIImage(cgImage: cg)
    let w = ci.extent.width
    let h = ci.extent.height

    // Normalized top-left origin -> CoreImage bottom-left origin (pixels).
    func point(_ i: Int) -> CGPoint {
      CGPoint(x: CGFloat(corners[i]) * w, y: (1 - CGFloat(corners[i + 1])) * h)
    }

    let filter = CIFilter.perspectiveCorrection()
    filter.inputImage = ci
    filter.topLeft = point(0)
    filter.topRight = point(2)
    filter.bottomRight = point(4)
    filter.bottomLeft = point(6)

    guard let output = filter.outputImage else { throw ProcessingError.render }
    return try writeJPEG(output)
  }

  /// Applies [filter] (`enhance` / `grayscale` / `blackWhite`) to [path].
  static func applyFilter(path: String, filter name: String) throws -> String {
    guard let cg = uprightCGImage(path: path) else { throw ProcessingError.decode }
    let ci = CIImage(cgImage: cg)
    let output: CIImage

    switch name {
    case "enhance":
      let f = CIFilter.colorControls()
      f.inputImage = ci
      f.saturation = 1.08
      f.contrast = 1.12
      f.brightness = 0.0
      output = f.outputImage ?? ci
    case "grayscale":
      let f = CIFilter.photoEffectMono()
      f.inputImage = ci
      output = f.outputImage ?? ci
    case "blackWhite":
      output = blackWhite(ci)
    default:
      output = ci
    }
    return try writeJPEG(output)
  }

  /// High-contrast bilevel look. Prefers `CIColorThreshold` (where available),
  /// otherwise crushes a monochrome image's contrast.
  private static func blackWhite(_ input: CIImage) -> CIImage {
    if let threshold = CIFilter(name: "CIColorThreshold") {
      threshold.setValue(input, forKey: kCIInputImageKey)
      threshold.setValue(0.5, forKey: "inputThreshold")
      if let out = threshold.outputImage { return out }
    }
    let mono = CIFilter.photoEffectMono()
    mono.inputImage = input
    let controls = CIFilter.colorControls()
    controls.inputImage = mono.outputImage ?? input
    controls.saturation = 0.0
    controls.contrast = 4.0
    controls.brightness = 0.0
    return controls.outputImage ?? input
  }

  /// Renders [image] to a JPEG in the temp directory and returns its path.
  private static func writeJPEG(_ image: CIImage) throws -> String {
    let dir = NSTemporaryDirectory() + "paper_scanner/"
    try? FileManager.default.createDirectory(
      atPath: dir, withIntermediateDirectories: true, attributes: nil
    )
    let path = dir + UUID().uuidString + ".jpg"
    let url = URL(fileURLWithPath: path)
    let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
    let options: [CIImageRepresentationOption: Any] = [
      CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String): jpegQuality
    ]
    try context.writeJPEGRepresentation(
      of: image, to: url, colorSpace: colorSpace, options: options
    )
    return path
  }
}
