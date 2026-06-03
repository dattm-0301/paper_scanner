import 'package:flutter_test/flutter_test.dart';
import 'package:paper_scanner/paper_scanner.dart';

void main() {
  group('PaperScannerOptions', () {
    test('detectionInterval is derived from detectionFps', () {
      expect(
        const PaperScannerOptions(detectionFps: 5).detectionInterval,
        const Duration(milliseconds: 200),
      );
      expect(
        const PaperScannerOptions(detectionFps: 10).detectionInterval,
        const Duration(milliseconds: 100),
      );
    });

    test('constructor assertions guard invalid configuration', () {
      expect(() => PaperScannerOptions(detectionFps: 0),
          throwsA(isA<AssertionError>()));
      expect(() => PaperScannerOptions(detectionFps: 31),
          throwsA(isA<AssertionError>()));
      expect(() => PaperScannerOptions(minPages: -1),
          throwsA(isA<AssertionError>()));
      expect(() => PaperScannerOptions(maxPages: -1),
          throwsA(isA<AssertionError>()));
      expect(() => PaperScannerOptions(minPages: 3, maxPages: 2),
          throwsA(isA<AssertionError>()));
    });

    test('valid min/max combinations are accepted', () {
      expect(() => const PaperScannerOptions(minPages: 2, maxPages: 0),
          returnsNormally); // 0 = unlimited
      expect(() => const PaperScannerOptions(minPages: 1, maxPages: 3),
          returnsNormally);
    });

    test('copyWith overrides only the provided fields', () {
      const base = PaperScannerOptions(
        outputPdf: true,
        maxPages: 3,
        detectionFps: 5,
      );
      final copy = base.copyWith(
        maxPages: 5,
        initialFilter: ScanFilter.grayscale,
      );

      expect(copy.outputPdf, isTrue); // preserved
      expect(copy.detectionFps, 5); // preserved
      expect(copy.maxPages, 5); // overridden
      expect(copy.initialFilter, ScanFilter.grayscale); // overridden
    });
  });
}
