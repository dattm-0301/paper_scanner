import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'paper_scanner_platform.dart';

/// Default [PaperScannerPlatform] implementation backed by a [MethodChannel].
///
/// The channel contract (channel name `paper_scanner`, method names and
/// argument maps) is mirrored exactly by the native Kotlin and Swift handlers.
/// This is intentionally hand-authored; the equivalent Pigeon definition lives
/// in `pigeons/messages.dart` for teams that prefer generated, typed wrappers.
class MethodChannelPaperScanner extends PaperScannerPlatform {
  /// The channel used to talk to the host platform.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('paper_scanner');

  @override
  Future<DetectedQuad?> detectInImage(String path) async {
    final result = await methodChannel.invokeMapMethod<Object?, Object?>(
      'detectInImage',
      <String, Object?>{'path': path},
    );
    return result == null ? null : DetectedQuad.fromMap(result);
  }

  @override
  Future<DetectedQuad?> detectInFrame(FrameData frame) async {
    final result = await methodChannel.invokeMapMethod<Object?, Object?>(
      'detectInFrame',
      frame.toMap(),
    );
    return result == null ? null : DetectedQuad.fromMap(result);
  }

  @override
  Future<String> cropPerspective(String path, Quad quad) async {
    final result = await methodChannel.invokeMethod<String>(
      'cropPerspective',
      <String, Object?>{'path': path, 'corners': quad.toList()},
    );
    if (result == null) {
      throw PlatformException(
        code: 'crop_failed',
        message: 'cropPerspective returned no output path',
      );
    }
    return result;
  }

  @override
  Future<String> applyFilter(String path, ScanFilter filter) async {
    // The original image needs no native round-trip.
    if (filter == ScanFilter.original) return path;
    final result = await methodChannel.invokeMethod<String>(
      'applyFilter',
      <String, Object?>{'path': path, 'filter': filter.wireName},
    );
    if (result == null) {
      throw PlatformException(
        code: 'filter_failed',
        message: 'applyFilter returned no output path',
      );
    }
    return result;
  }

  @override
  Future<String> rotate(String path, int quarterTurns) async {
    final turns = quarterTurns % 4;
    // A zero rotation needs no native round-trip.
    if (turns == 0) return path;
    final result = await methodChannel.invokeMethod<String>(
      'rotate',
      <String, Object?>{'path': path, 'quarterTurns': turns},
    );
    if (result == null) {
      throw PlatformException(
        code: 'rotate_failed',
        message: 'rotate returned no output path',
      );
    }
    return result;
  }
}
