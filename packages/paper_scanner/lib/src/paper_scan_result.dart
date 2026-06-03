import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

/// One page captured during a scan session.
///
/// A page moves through three optional stages: the raw [originalPath] capture,
/// the perspective-corrected [croppedPath], and the [filteredPath] after a
/// [ScanFilter] is applied. [outputPath] always resolves to the best available
/// version.
class ScannedPage {
  ScannedPage({
    required this.originalPath,
    this.quad,
    this.croppedPath,
    this.filteredPath,
    this.filter = ScanFilter.original,
  });

  /// The unmodified capture from the camera.
  final String originalPath;

  /// Detected or user-adjusted corners used for the perspective crop.
  Quad? quad;

  /// Path to the perspective-corrected image, once cropped.
  String? croppedPath;

  /// Path to the filtered image, when a non-original [filter] is applied.
  String? filteredPath;

  /// The filter currently applied to this page.
  ScanFilter filter;

  /// The best available representation: filtered → cropped → original.
  String get outputPath => filteredPath ?? croppedPath ?? originalPath;
}

/// The result returned by a scan session.
class PaperScanResult {
  const PaperScanResult({required this.imagePaths, this.pdfPath});

  /// Final, processed image paths — one per page, in page order.
  final List<String> imagePaths;

  /// Assembled multi-page PDF path, present only when
  /// [PaperScannerOptions.outputPdf] is enabled and at least one page exists.
  final String? pdfPath;

  /// Whether the session produced no pages.
  bool get isEmpty => imagePaths.isEmpty;

  /// Number of scanned pages.
  int get pageCount => imagePaths.length;

  @override
  String toString() => 'PaperScanResult(pages: ${imagePaths.length}, pdf: $pdfPath)';
}
