/// A fully custom, themeable Flutter document scanner.
///
/// Live camera preview with realtime edge detection, draggable corner crop,
/// filters, multi-page capture and optional PDF output — all rendered with
/// Flutter widgets you can restyle and localize via [PaperScannerStyle].
///
/// ```dart
/// final result = await PaperScanner.open(
///   context,
///   options: const PaperScannerOptions(outputPdf: true),
///   style: PaperScannerStyle(accentColor: Colors.teal),
/// );
/// if (result != null) {
///   // result.imagePaths, result.pdfPath
/// }
/// ```
library paper_document_scanner;

import 'package:flutter/material.dart';

import 'src/paper_scan_result.dart';
import 'src/paper_scanner_options.dart';
import 'src/paper_scanner_style.dart';
import 'src/ui/paper_scanner_screen.dart';

// Public model types re-exported from the platform interface.
export 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart'
    show ScanFilter, Quad, ScanPoint, DetectedQuad;

export 'src/paper_scan_result.dart';
export 'src/paper_scanner_controller.dart'
    show PaperScannerController, ScanStage;
export 'src/paper_scanner_options.dart';
export 'src/paper_scanner_style.dart';
export 'src/pdf_builder.dart' show buildPdf, PdfAssembler;
export 'src/ui/page_editor_view.dart' show PageEditorScreen;
export 'src/ui/paper_scanner_screen.dart' show PaperScannerScreen;

/// One-line entry point for launching the scanner.
abstract final class PaperScanner {
  const PaperScanner._();

  /// Pushes the [PaperScannerScreen] and resolves to the scan result, or `null`
  /// if the user cancelled.
  ///
  /// [options] tunes behavior (PDF output, max pages, live detection); [style]
  /// controls every visual aspect and label. By default the route is presented
  /// as a fullscreen dialog.
  static Future<PaperScanResult?> open(
    BuildContext context, {
    PaperScannerOptions options = const PaperScannerOptions(),
    PaperScannerStyle style = const PaperScannerStyle(),
    bool fullscreenDialog = true,
  }) {
    return Navigator.of(context).push<PaperScanResult>(
      MaterialPageRoute<PaperScanResult>(
        fullscreenDialog: fullscreenDialog,
        builder: (_) => PaperScannerScreen(options: options, style: style),
      ),
    );
  }
}
