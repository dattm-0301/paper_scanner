import 'package:flutter_test/flutter_test.dart';
import 'package:paper_document_scanner/paper_document_scanner.dart';

void main() {
  group('ScannedPage.outputPath', () {
    test('prefers rotated, then filtered, then cropped, then original', () {
      final page = ScannedPage(originalPath: 'o.jpg');
      expect(page.outputPath, 'o.jpg');

      page.croppedPath = 'c.jpg';
      expect(page.outputPath, 'c.jpg');

      page.filteredPath = 'f.jpg';
      expect(page.outputPath, 'f.jpg');

      page.rotatedPath = 'r.jpg';
      expect(page.outputPath, 'r.jpg');
      // processedPath is the pre-rotation image (filter → crop → original).
      expect(page.processedPath, 'f.jpg');
    });
  });

  group('PaperScanResult', () {
    test('reports emptiness and page count', () {
      const empty = PaperScanResult(imagePaths: []);
      expect(empty.isEmpty, isTrue);
      expect(empty.pageCount, 0);

      const result = PaperScanResult(
        imagePaths: ['a.jpg', 'b.jpg'],
        pdfPath: 'out.pdf',
      );
      expect(result.isEmpty, isFalse);
      expect(result.pageCount, 2);
      expect(result.pdfPath, 'out.pdf');
    });

    test('toString summarizes pages and pdf', () {
      const result = PaperScanResult(imagePaths: ['a.jpg'], pdfPath: 'x.pdf');
      expect(result.toString(), contains('pages: 1'));
      expect(result.toString(), contains('x.pdf'));
    });

    test('pages defaults to empty and carries per-page detail', () {
      const bare = PaperScanResult(imagePaths: ['a.jpg']);
      expect(bare.pages, isEmpty);

      const result = PaperScanResult(
        imagePaths: ['a.jpg'],
        pages: [
          ScannedPageResult(
            path: 'a.jpg',
            originalPath: 'raw.jpg',
            filter: ScanFilter.grayscale,
            rotationTurns: 1,
            quad: null,
          ),
        ],
      );
      final page = result.pages.single;
      expect(page.path, 'a.jpg');
      expect(page.originalPath, 'raw.jpg');
      expect(page.filter, ScanFilter.grayscale);
      expect(page.rotationTurns, 1);
    });
  });
}
