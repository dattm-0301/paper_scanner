import 'package:flutter_test/flutter_test.dart';
import 'package:paper_document_scanner/paper_document_scanner.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

/// In-memory platform that mimics native behavior by deriving deterministic
/// output paths, so the controller's state machine can be tested without a
/// device.
class _FakePlatform extends PaperScannerPlatform {
  int detectInImageCalls = 0;

  @override
  Future<DetectedQuad?> detectInImage(String path) async {
    detectInImageCalls++;
    return DetectedQuad(quad: Quad.full(), confidence: 0.9);
  }

  @override
  Future<DetectedQuad?> detectInFrame(FrameData frame) async {
    return DetectedQuad(quad: Quad.full(), confidence: 0.5);
  }

  @override
  Future<String> cropPerspective(String path, Quad quad) async =>
      '$path.cropped';

  @override
  Future<String> applyFilter(String path, ScanFilter filter) async {
    if (filter == ScanFilter.original) return path;
    return '$path.${filter.wireName}';
  }

  @override
  Future<String> rotate(String path, int quarterTurns) async =>
      '$path.r$quarterTurns';
}

void main() {
  late _FakePlatform platform;

  // These tests exercise the explicit Retake/Keep confirm flow, so force it on.
  // The default (seamless auto-keep) flow is covered separately below.
  PaperScannerController makeController(PaperScannerOptions options) {
    return PaperScannerController(
      options: options.copyWith(confirmAfterCapture: true),
      platform: platform,
      pdfAssembler: (paths) async => 'assembled_${paths.length}.pdf',
    );
  }

  setUp(() => platform = _FakePlatform());

  test('capture → crop → keep → finish flow', () async {
    final controller = makeController(
      const PaperScannerOptions(outputPdf: true),
    );
    expect(controller.stage, ScanStage.initializing);

    controller.markCameraReady();
    expect(controller.stage, ScanStage.camera);

    await controller.onCaptured('/page_a.jpg');
    expect(controller.stage, ScanStage.crop);
    expect(controller.draft?.quad, Quad.full());
    expect(platform.detectInImageCalls, 1);

    await controller.keepDraft();
    expect(controller.stage, ScanStage.camera);
    expect(controller.pageCount, 1);
    expect(controller.draft, isNull);
    // Default filter is original → output is the cropped image.
    expect(controller.pages.single.outputPath, '/page_a.jpg.cropped');

    await controller.onCaptured('/page_b.jpg');
    await controller.keepDraft();

    final result = await controller.finish();
    expect(controller.stage, ScanStage.finished);
    expect(result.imagePaths, ['/page_a.jpg.cropped', '/page_b.jpg.cropped']);
    expect(result.pdfPath, 'assembled_2.pdf');
  });

  test('sessionFilter is applied on keep', () async {
    final controller = makeController(const PaperScannerOptions());
    controller.setSessionFilter(ScanFilter.grayscale);
    await controller.onCaptured('/p.jpg');
    await controller.keepDraft();
    expect(controller.pages.single.outputPath, '/p.jpg.cropped.grayscale');
    expect(controller.pages.single.filter, ScanFilter.grayscale);
  });

  test('initialFilter seeds the session filter', () async {
    final controller = makeController(
      const PaperScannerOptions(initialFilter: ScanFilter.blackWhite),
    );
    expect(controller.sessionFilter, ScanFilter.blackWhite);
    await controller.onCaptured('/p.jpg');
    await controller.keepDraft();
    expect(controller.pages.single.outputPath, '/p.jpg.cropped.blackWhite');
  });

  test('finish without outputPdf yields no pdf', () async {
    final controller = makeController(const PaperScannerOptions());
    await controller.onCaptured('/p.jpg');
    await controller.keepDraft();
    final result = await controller.finish();
    expect(result.pdfPath, isNull);
    expect(result.imagePaths.single, '/p.jpg.cropped');
  });

  test('retakeDraft discards the current draft', () async {
    final controller = makeController(const PaperScannerOptions());
    await controller.onCaptured('/p.jpg');
    expect(controller.draft, isNotNull);
    controller.retakeDraft();
    expect(controller.draft, isNull);
    expect(controller.stage, ScanStage.camera);
  });

  test('maxPages gates canAddMore', () async {
    final controller = makeController(const PaperScannerOptions(maxPages: 1));
    expect(controller.canAddMore, isTrue);
    await controller.onCaptured('/p.jpg');
    await controller.keepDraft();
    expect(controller.pageCount, 1);
    expect(controller.canAddMore, isFalse);
  });

  test('minPages gates canFinish', () async {
    final controller = makeController(const PaperScannerOptions(minPages: 2));
    expect(controller.canFinish, isFalse);

    await controller.onCaptured('/1.jpg');
    await controller.keepDraft();
    expect(controller.canFinish, isFalse);

    await controller.onCaptured('/2.jpg');
    await controller.keepDraft();
    expect(controller.canFinish, isTrue);
  });

  test('autoCapture defaults on and toggles', () {
    final controller = makeController(const PaperScannerOptions());
    expect(controller.autoCapture, isTrue); // on by default
    controller.toggleAutoCapture();
    expect(controller.autoCapture, isFalse);
  });

  test('autoCapture can be disabled via options', () {
    final controller = PaperScannerController(
      options: const PaperScannerOptions(autoCapture: false),
      platform: platform,
    );
    expect(controller.autoCapture, isFalse);
  });

  group('seamless capture (default flow)', () {
    test('onCaptured commits immediately without a confirm step', () async {
      final controller = PaperScannerController(
        options: const PaperScannerOptions(),
        platform: platform,
      );
      controller.markCameraReady();

      await controller.onCaptured('/page.jpg');

      expect(controller.stage, ScanStage.camera);
      expect(controller.draft, isNull);
      expect(controller.pageCount, 1);
      expect(controller.pages.single.outputPath, '/page.jpg.cropped');
    });

    test('seamless capture applies the active session filter', () async {
      final controller = PaperScannerController(
        options: const PaperScannerOptions(initialFilter: ScanFilter.grayscale),
        platform: platform,
      );
      await controller.onCaptured('/p.jpg');
      expect(controller.pages.single.outputPath, '/p.jpg.cropped.grayscale');
    });
  });

  group('per-page edits (detail view)', () {
    Future<PaperScannerController> onePage(ScanFilter initial) async {
      final controller = PaperScannerController(
        options: PaperScannerOptions(initialFilter: initial),
        platform: platform,
      );
      await controller.onCaptured('/p.jpg'); // seamless commit
      return controller;
    }

    test('rotatePage cycles 0→1→…→0 and rotates the output', () async {
      final controller = await onePage(ScanFilter.original);
      expect(controller.pages.single.rotationTurns, 0);
      expect(controller.pages.single.outputPath, '/p.jpg.cropped');

      await controller.rotatePage(0);
      expect(controller.pages.single.rotationTurns, 1);
      expect(controller.pages.single.outputPath, '/p.jpg.cropped.r1');

      await controller.rotatePage(0);
      await controller.rotatePage(0);
      await controller.rotatePage(0); // back to 0
      expect(controller.pages.single.rotationTurns, 0);
      expect(controller.pages.single.outputPath, '/p.jpg.cropped');
    });

    test('setPageFilter re-derives the filtered output', () async {
      final controller = await onePage(ScanFilter.original);
      await controller.setPageFilter(0, ScanFilter.grayscale);
      expect(controller.pages.single.filter, ScanFilter.grayscale);
      expect(controller.pages.single.outputPath, '/p.jpg.cropped.grayscale');
    });

    test('recropPage re-crops then re-applies filter and rotation', () async {
      final controller = await onePage(ScanFilter.grayscale);
      await controller.rotatePage(0); // rotationTurns == 1

      await controller.recropPage(0, Quad.full());

      final page = controller.pages.single;
      expect(page.croppedPath, '/p.jpg.cropped');
      expect(page.filteredPath, '/p.jpg.cropped.grayscale');
      expect(page.rotationTurns, 1);
      expect(page.outputPath, '/p.jpg.cropped.grayscale.r1');
    });

    test('edits on an out-of-range index are no-ops', () async {
      final controller = await onePage(ScanFilter.original);
      await controller.rotatePage(5);
      await controller.setPageFilter(-1, ScanFilter.enhance);
      await controller.recropPage(9, Quad.full());
      expect(controller.pages.single.rotationTurns, 0);
      expect(controller.pages.single.filter, ScanFilter.original);
    });
  });

  test('deletePage and reorderPages mutate committed pages', () async {
    final controller = makeController(const PaperScannerOptions());

    Future<void> addPage(String path) async {
      await controller.onCaptured(path);
      await controller.keepDraft();
    }

    await addPage('/1.jpg');
    await addPage('/2.jpg');
    await addPage('/3.jpg');
    expect(controller.pageCount, 3);

    controller.reorderPages(0, 3); // move first to last
    expect(controller.pages.first.originalPath, '/2.jpg');
    expect(controller.pages.last.originalPath, '/1.jpg');

    controller.deletePage(0);
    expect(controller.pageCount, 2);
    expect(controller.pages.first.originalPath, '/3.jpg');
  });

  group('finish result', () {
    test('returns per-page detail reflecting edits', () async {
      final controller = PaperScannerController(
        options: const PaperScannerOptions(initialFilter: ScanFilter.grayscale),
        platform: platform,
      );
      await controller.onCaptured('/p.jpg'); // seamless commit (grayscale)
      await controller.rotatePage(0); // rotationTurns -> 1

      final result = await controller.finish();

      expect(result.pageCount, 1);
      expect(result.pages, hasLength(1));
      final page = result.pages.single;
      expect(page.originalPath, '/p.jpg');
      expect(page.filter, ScanFilter.grayscale);
      expect(page.rotationTurns, 1);
      expect(page.quad, isNotNull);
      expect(page.path, '/p.jpg.cropped.grayscale.r1');
      expect(result.imagePaths.single, page.path); // imagePaths mirrors pages
    });

    test('result order follows reorder', () async {
      final controller = PaperScannerController(
        options: const PaperScannerOptions(),
        platform: platform,
      );
      await controller.onCaptured('/a.jpg');
      await controller.onCaptured('/b.jpg');
      controller.reorderPages(0, 2); // move first to last -> [b, a]

      final result = await controller.finish();

      expect(
        result.pages.map((p) => p.originalPath).toList(),
        ['/b.jpg', '/a.jpg'],
      );
      expect(result.imagePaths, ['/b.jpg.cropped', '/a.jpg.cropped']);
    });
  });
}
