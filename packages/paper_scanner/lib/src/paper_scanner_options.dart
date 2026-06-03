import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

/// Behavioral configuration for a scan session (separate from visual
/// [PaperScannerStyle]).
class PaperScannerOptions {
  const PaperScannerOptions({
    this.outputPdf = false,
    this.minPages = 0,
    this.maxPages = 0,
    this.initialFilter = ScanFilter.original,
    this.enableLiveDetection = true,
    this.detectionFps = 5,
    this.autoConfirmSinglePage = false,
  }) : assert(detectionFps > 0 && detectionFps <= 30),
       assert(minPages >= 0),
       assert(maxPages >= 0),
       assert(maxPages == 0 || minPages <= maxPages);

  /// When `true`, the result includes an assembled multi-page PDF
  /// ([PaperScanResult.pdfPath]).
  final bool outputPdf;

  /// Minimum number of pages required before the session can finish.
  final int minPages;

  /// Maximum number of pages; `0` means unlimited.
  final int maxPages;

  /// Filter applied to a page immediately after cropping.
  final ScanFilter initialFilter;

  /// Whether to run realtime edge detection on the live preview.
  final bool enableLiveDetection;

  /// Target frames-per-second for realtime detection. The preview stream is
  /// throttled to roughly this rate (and skips frames while a detection is in
  /// flight) to keep the UI smooth.
  final int detectionFps;

  /// When `true` and [maxPages] is 1, the session finishes automatically after
  /// the first page's filter step instead of showing add/done controls.
  final bool autoConfirmSinglePage;

  /// Minimum interval between processed preview frames, derived from
  /// [detectionFps].
  Duration get detectionInterval =>
      Duration(milliseconds: (1000 / detectionFps).round());

  PaperScannerOptions copyWith({
    bool? outputPdf,
    int? minPages,
    int? maxPages,
    ScanFilter? initialFilter,
    bool? enableLiveDetection,
    int? detectionFps,
    bool? autoConfirmSinglePage,
  }) {
    return PaperScannerOptions(
      outputPdf: outputPdf ?? this.outputPdf,
      minPages: minPages ?? this.minPages,
      maxPages: maxPages ?? this.maxPages,
      initialFilter: initialFilter ?? this.initialFilter,
      enableLiveDetection: enableLiveDetection ?? this.enableLiveDetection,
      detectionFps: detectionFps ?? this.detectionFps,
      autoConfirmSinglePage:
          autoConfirmSinglePage ?? this.autoConfirmSinglePage,
    );
  }
}
