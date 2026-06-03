// Pigeon definition for the paper_scanner host API.
//
// This is the *typed* contract that mirrors the hand-authored MethodChannel in
// `lib/src/method_channel_paper_scanner.dart`. It is provided so teams that
// prefer generated, type-safe channel code can migrate without redesigning the
// API. Regenerate with:
//
//   dart run pigeon --input pigeons/messages.dart
//
// (configuration is embedded below via @ConfigurePigeon). After regenerating,
// switch `MethodChannelPaperScanner` to call the generated `PaperScannerApi`
// and implement the generated host-side interfaces in Kotlin/Swift.
//
// NOTE: not wired into the build by default — the shipping implementation uses
// the hand-authored channel so the package compiles without running codegen.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut:
        '../paper_scanner_android/android/src/main/kotlin/dev/paperscanner/paper_scanner_android/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.paperscanner.paper_scanner_android'),
    swiftOut: '../paper_scanner_ios/ios/Classes/Messages.g.swift',
    dartPackageName: 'paper_scanner_platform_interface',
  ),
)

/// Pigeon mirror of `FrameFormat`.
enum PigeonFrameFormat { yuv420, bgra8888 }

/// Pigeon mirror of `ScanFilter`.
enum PigeonScanFilter { original, enhance, grayscale, blackWhite }

/// A normalized quad result. Corners are normalized `0..1`, top-left origin,
/// in order TL, TR, BR, BL flattened to 8 doubles.
class PigeonDetectedQuad {
  PigeonDetectedQuad(this.corners, this.confidence);
  List<double> corners;
  double confidence;
}

/// A single downscaled preview frame for realtime detection.
class PigeonFrameData {
  PigeonFrameData(
    this.bytes,
    this.width,
    this.height,
    this.bytesPerRow,
    this.rotation,
    this.format,
  );
  Uint8List bytes;
  int width;
  int height;
  int bytesPerRow;
  int rotation;
  PigeonFrameFormat format;
}

@HostApi()
abstract class PaperScannerApi {
  @async
  PigeonDetectedQuad? detectInImage(String path);

  @async
  PigeonDetectedQuad? detectInFrame(PigeonFrameData frame);

  @async
  String cropPerspective(String path, List<double> corners);

  @async
  String applyFilter(String path, PigeonScanFilter filter);
}
