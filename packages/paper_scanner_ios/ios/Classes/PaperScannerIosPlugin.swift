import Flutter
import UIKit

/// iOS implementation of the `paper_scanner` plugin.
///
/// Registers a `FlutterMethodChannel` named `paper_scanner` mirroring the Dart
/// `MethodChannelPaperScanner` contract. Vision/CoreImage work runs on a
/// background queue; results are delivered on the main thread.
public class PaperScannerIosPlugin: NSObject, FlutterPlugin {

  private static let channelName = "paper_scanner"
  private static let errorCode = "paper_scanner_error"

  private let workQueue = DispatchQueue(label: "dev.paperscanner.work", qos: .userInitiated)

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = PaperScannerIosPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    workQueue.async {
      switch call.method {
      case "detectInImage":
        self.handleDetectInImage(call, result)
      case "detectInFrame":
        self.handleDetectInFrame(call, result)
      case "cropPerspective":
        self.handleCropPerspective(call, result)
      case "applyFilter":
        self.handleApplyFilter(call, result)
      default:
        self.reply(result, FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Handlers

  private func handleDetectInImage(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String else {
      return reply(result, argError())
    }
    guard let cgImage = ImageProcessor.uprightCGImage(path: path) else {
      return reply(result, nil)
    }
    let detected = DocumentDetector.detect(in: cgImage, orientation: .up)
    reply(result, detected?.toReply())
  }

  private func handleDetectInFrame(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let typed = args["bytes"] as? FlutterStandardTypedData,
          let width = args["width"] as? Int,
          let height = args["height"] as? Int else {
      return reply(result, argError())
    }
    let bytesPerRow = args["bytesPerRow"] as? Int ?? width * 4
    let rotation = args["rotation"] as? Int ?? 0
    let format = args["format"] as? String ?? "bgra8888"

    guard let cgImage = DocumentDetector.cgImage(
      from: typed.data, width: width, height: height,
      bytesPerRow: bytesPerRow, format: format
    ) else {
      return reply(result, nil)
    }
    let detected = DocumentDetector.detect(
      in: cgImage,
      orientation: DocumentDetector.orientation(forRotation: rotation)
    )
    reply(result, detected?.toReply())
  }

  private func handleCropPerspective(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          let rawCorners = args["corners"] as? [NSNumber], rawCorners.count == 8 else {
      return reply(result, argError())
    }
    let corners = rawCorners.map { $0.doubleValue }
    do {
      let outPath = try ImageProcessor.cropPerspective(path: path, corners: corners)
      reply(result, outPath)
    } catch {
      reply(result, self.error(error))
    }
  }

  private func handleApplyFilter(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let path = args["path"] as? String else {
      return reply(result, argError())
    }
    let filter = args["filter"] as? String ?? "original"
    do {
      let outPath = try ImageProcessor.applyFilter(path: path, filter: filter)
      reply(result, outPath)
    } catch {
      reply(result, self.error(error))
    }
  }

  // MARK: - Reply helpers

  private func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  private func argError() -> FlutterError {
    FlutterError(code: Self.errorCode, message: "Invalid or missing arguments", details: nil)
  }

  private func error(_ error: Error) -> FlutterError {
    FlutterError(code: Self.errorCode, message: error.localizedDescription, details: nil)
  }
}
