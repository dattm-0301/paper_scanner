import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Assembles [imagePaths] into a single file and returns its path.
///
/// Injected into [PaperScannerController] so tests can substitute a fake and
/// consumers can swap in their own assembler if needed.
typedef PdfAssembler = Future<String> Function(List<String> imagePaths);

/// Default [PdfAssembler]: one image per A4 page, centered and scaled to fit.
Future<String> buildPdf(List<String> imagePaths) async {
  final document = pw.Document();
  for (final path in imagePaths) {
    final bytes = await File(path).readAsBytes();
    final image = pw.MemoryImage(bytes);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (context) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
  }

  final dir = await getTemporaryDirectory();
  final outPath =
      '${dir.path}/paper_scanner_${DateTime.now().millisecondsSinceEpoch}.pdf';
  final file = File(outPath);
  await file.writeAsBytes(await document.save());
  return outPath;
}
