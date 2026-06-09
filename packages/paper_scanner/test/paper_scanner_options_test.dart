import 'package:flutter_test/flutter_test.dart';
import 'package:paper_document_scanner/paper_document_scanner.dart';

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
      expect(
        () => PaperScannerOptions(detectionFps: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => PaperScannerOptions(detectionFps: 31),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => PaperScannerOptions(minPages: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => PaperScannerOptions(maxPages: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => PaperScannerOptions(minPages: 3, maxPages: 2),
        throwsA(isA<AssertionError>()),
      );
    });

    test('valid min/max combinations are accepted', () {
      expect(
        () => const PaperScannerOptions(minPages: 2, maxPages: 0),
        returnsNormally,
      ); // 0 = unlimited
      expect(
        () => const PaperScannerOptions(minPages: 1, maxPages: 3),
        returnsNormally,
      );
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

    test('capture-flow defaults and copyWith', () {
      const base = PaperScannerOptions();
      expect(base.autoCapture, isTrue); // on by default
      expect(base.confirmAfterCapture, isFalse); // seamless by default

      final copy = base.copyWith(autoCapture: false, confirmAfterCapture: true);
      expect(copy.autoCapture, isFalse);
      expect(copy.confirmAfterCapture, isTrue);
    });

    test('auto-capture tuning defaults', () {
      const o = PaperScannerOptions();
      expect(o.autoCaptureConfidence, 0.66);
      expect(o.autoCaptureStableFrames, 3);
      expect(o.autoCaptureMotionTolerance, 0.025);
      expect(o.detectionFps, 10); // snappier default cadence
    });

    test('auto-capture tuning is overridable via copyWith', () {
      final copy = const PaperScannerOptions().copyWith(
        autoCaptureConfidence: 0.8,
        autoCaptureStableFrames: 5,
        autoCaptureMotionTolerance: 0.05,
      );
      expect(copy.autoCaptureConfidence, 0.8);
      expect(copy.autoCaptureStableFrames, 5);
      expect(copy.autoCaptureMotionTolerance, 0.05);
    });

    test('auto-capture tuning assertions guard invalid values', () {
      expect(
        () => PaperScannerOptions(autoCaptureConfidence: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => PaperScannerOptions(autoCaptureConfidence: 1.5),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => PaperScannerOptions(autoCaptureStableFrames: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => PaperScannerOptions(autoCaptureMotionTolerance: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
