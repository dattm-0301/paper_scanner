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
    this.detectionFps = 10,
    this.autoConfirmSinglePage = false,
    this.autoCapture = true,
    this.confirmAfterCapture = false,
    this.autoCaptureConfidence = 0.66,
    this.autoCaptureStableFrames = 3,
    this.autoCaptureMotionTolerance = 0.025,
  }) : assert(detectionFps > 0 && detectionFps <= 30),
       assert(minPages >= 0),
       assert(maxPages >= 0),
       assert(maxPages == 0 || minPages <= maxPages),
       assert(autoCaptureConfidence > 0 && autoCaptureConfidence <= 1),
       assert(autoCaptureStableFrames >= 1),
       assert(
         autoCaptureMotionTolerance > 0 && autoCaptureMotionTolerance <= 1,
       );

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
  /// flight) to keep the UI smooth. Higher values make the edge overlay track
  /// the document more responsively at some CPU cost; defaults to 10.
  final int detectionFps;

  /// When `true` and [maxPages] is 1, the session finishes automatically after
  /// the first page's filter step instead of showing add/done controls.
  final bool autoConfirmSinglePage;

  /// Initial state of the auto-capture toggle. When `true` (the default) the
  /// scanner shoots automatically once a confident, stable document quad is
  /// held in frame — the user does not have to tap the shutter. The manual
  /// shutter button stays available either way.
  final bool autoCapture;

  /// When `true`, each capture pauses on a Retake / Keep crop-confirm step
  /// before the page is committed (the legacy flow). When `false` (the default)
  /// captures commit immediately with the detected crop — matching the native
  /// OS scanners — and corrections happen later in the detail/edit view.
  final bool confirmAfterCapture;

  /// Minimum detection confidence (`0..1`) a live quad must reach before
  /// auto-capture will consider it. Lower = fires on weaker detections.
  /// Defaults to `0.66`.
  final double autoCaptureConfidence;

  /// Number of consecutive "still" detections required before auto-capture
  /// fires. Higher = the document must be held steady longer. Defaults to `3`
  /// (≈0.3s at the default [detectionFps]).
  final int autoCaptureStableFrames;

  /// Maximum movement of any quad corner between two detections, as a fraction
  /// of the frame, still counted as "still". Larger = more tolerant of shake
  /// (fires sooner); smaller = demands a steadier hold. Defaults to `0.025`.
  final double autoCaptureMotionTolerance;

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
    bool? autoCapture,
    bool? confirmAfterCapture,
    double? autoCaptureConfidence,
    int? autoCaptureStableFrames,
    double? autoCaptureMotionTolerance,
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
      autoCapture: autoCapture ?? this.autoCapture,
      confirmAfterCapture: confirmAfterCapture ?? this.confirmAfterCapture,
      autoCaptureConfidence:
          autoCaptureConfidence ?? this.autoCaptureConfidence,
      autoCaptureStableFrames:
          autoCaptureStableFrames ?? this.autoCaptureStableFrames,
      autoCaptureMotionTolerance:
          autoCaptureMotionTolerance ?? this.autoCaptureMotionTolerance,
    );
  }
}
