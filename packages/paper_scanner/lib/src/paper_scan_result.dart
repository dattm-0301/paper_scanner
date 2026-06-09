import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

/// One page captured during a scan session.
///
/// A page is the source of truth for the edit pipeline applied in the detail
/// view: the raw [originalPath] is perspective-cropped with [quad] → produces
/// [croppedPath]; a non-original [filter] → produces [filteredPath]; a non-zero
/// [rotationTurns] → produces [rotatedPath]. [outputPath] always resolves to the
/// best (latest) available version.
class ScannedPage {
  ScannedPage({
    required this.originalPath,
    this.quad,
    this.croppedPath,
    this.filteredPath,
    this.rotatedPath,
    this.filter = ScanFilter.original,
    this.rotationTurns = 0,
  });

  /// The unmodified capture from the camera.
  final String originalPath;

  /// Detected or user-adjusted corners used for the perspective crop.
  Quad? quad;

  /// Path to the perspective-corrected image, once cropped.
  String? croppedPath;

  /// Path to the filtered image, when a non-original [filter] is applied.
  String? filteredPath;

  /// Path to the rotated image, when [rotationTurns] is non-zero. Always the
  /// final step of the pipeline (applied on top of crop + filter).
  String? rotatedPath;

  /// The filter currently applied to this page.
  ScanFilter filter;

  /// Clockwise rotation applied to the page, in quarter turns (0–3).
  int rotationTurns;

  /// The cropped-then-filtered image, before rotation. Falls back to the
  /// original capture when no crop has run yet.
  String get processedPath => filteredPath ?? croppedPath ?? originalPath;

  /// The best available representation: rotated → filtered → cropped → original.
  String get outputPath =>
      rotatedPath ?? filteredPath ?? croppedPath ?? originalPath;
}

/// Per-page detail in a [PaperScanResult].
///
/// Carries both the final processed [path] and the inputs that produced it
/// (the raw [originalPath], the [filter], the [rotationTurns] and the crop
/// [quad]) so a consuming app can re-derive, re-edit or audit a page rather
/// than only receiving the flattened image path.
class ScannedPageResult {
  const ScannedPageResult({
    required this.path,
    required this.originalPath,
    required this.filter,
    required this.rotationTurns,
    this.quad,
  });

  /// The final processed image (cropped → filtered → rotated). Matches the
  /// corresponding entry in [PaperScanResult.imagePaths].
  final String path;

  /// The unmodified camera capture this page was derived from.
  final String originalPath;

  /// The filter applied to this page.
  final ScanFilter filter;

  /// Clockwise rotation applied, in quarter turns (0–3).
  final int rotationTurns;

  /// The crop corners (on [originalPath]) used for the perspective correction.
  final Quad? quad;

  @override
  String toString() =>
      'ScannedPageResult(path: $path, filter: ${filter.wireName}, '
      'rotationTurns: $rotationTurns)';
}

/// The result returned by a scan session.
class PaperScanResult {
  const PaperScanResult({
    required this.imagePaths,
    this.pdfPath,
    this.pages = const <ScannedPageResult>[],
  });

  /// Final, processed image paths — one per page, in page order. Equivalent to
  /// `pages.map((p) => p.path)`; kept as a convenience and for back-compat.
  final List<String> imagePaths;

  /// Assembled multi-page PDF path, present only when
  /// [PaperScannerOptions.outputPdf] is enabled and at least one page exists.
  final String? pdfPath;

  /// Per-page detail (final path + original + filter + rotation + crop quad),
  /// in page order. Empty only when the session produced no pages.
  final List<ScannedPageResult> pages;

  /// Whether the session produced no pages.
  bool get isEmpty => imagePaths.isEmpty;

  /// Number of scanned pages.
  int get pageCount => imagePaths.length;

  @override
  String toString() =>
      'PaperScanResult(pages: ${imagePaths.length}, pdf: $pdfPath)';
}
