import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_paper_scanner.dart';
import 'models.dart';

/// The interface every platform implementation of `paper_scanner` extends.
///
/// Implementations must use `extends` (not `implements`) so that new methods
/// added here do not silently break existing subclasses — enforced by
/// [PlatformInterface] via the private [_token].
///
/// The default [instance] is [MethodChannelPaperScanner]; native packages
/// register their own [MethodChannel] handler under the shared channel name, so
/// no extra Dart registration is required for the bundled Android/iOS
/// implementations.
abstract class PaperScannerPlatform extends PlatformInterface {
  /// Constructs a platform implementation, passing the verification [_token].
  PaperScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static PaperScannerPlatform _instance = MethodChannelPaperScanner();

  /// The active platform implementation.
  static PaperScannerPlatform get instance => _instance;

  /// Overrides the implementation (used by alternate implementations and tests).
  ///
  /// The provided [instance] must have been created with the same [_token],
  /// which [PlatformInterface.verifyToken] checks.
  static set instance(PaperScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Detects the largest document-like quadrilateral in a captured still image
  /// at [path]. Returns `null` when nothing confident is found.
  Future<DetectedQuad?> detectInImage(String path) {
    throw UnimplementedError('detectInImage() has not been implemented.');
  }

  /// Runs lightweight realtime detection on a single downscaled preview
  /// [frame]. Returns `null` when no quad is found.
  Future<DetectedQuad?> detectInFrame(FrameData frame) {
    throw UnimplementedError('detectInFrame() has not been implemented.');
  }

  /// Applies a perspective ("keystone") correction to the image at [path] using
  /// the normalized [quad], writing the warped result to a new file and
  /// returning its path.
  Future<String> cropPerspective(String path, Quad quad) {
    throw UnimplementedError('cropPerspective() has not been implemented.');
  }

  /// Applies [filter] to the image at [path], writing the result to a new file
  /// and returning its path. Implementations may return [path] unchanged for
  /// [ScanFilter.original].
  Future<String> applyFilter(String path, ScanFilter filter) {
    throw UnimplementedError('applyFilter() has not been implemented.');
  }

  /// Rotates the image at [path] clockwise by [quarterTurns] × 90°, writing the
  /// result to a new file and returning its path.
  ///
  /// [quarterTurns] is normalized modulo 4; `0` is a no-op and implementations
  /// may return [path] unchanged. Used by the detail-view "rotate" tool, so it
  /// runs on already cropped/filtered page images.
  Future<String> rotate(String path, int quarterTurns) {
    throw UnimplementedError('rotate() has not been implemented.');
  }
}
