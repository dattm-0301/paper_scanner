import 'package:flutter_test/flutter_test.dart';
import 'package:paper_scanner/paper_scanner.dart';

void main() {
  group('ScannedPage.outputPath', () {
    test('prefers filtered, then cropped, then original', () {
      final page = ScannedPage(originalPath: 'o.jpg');
      expect(page.outputPath, 'o.jpg');

      page.croppedPath = 'c.jpg';
      expect(page.outputPath, 'c.jpg');

      page.filteredPath = 'f.jpg';
      expect(page.outputPath, 'f.jpg');
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
  });
}
