import 'package:flutter_test/flutter_test.dart';
import 'package:paper_scanner/paper_scanner.dart';
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
}

void main() {
  late _FakePlatform platform;

  PaperScannerController makeController(PaperScannerOptions options) {
    return PaperScannerController(
      options: options,
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

  test('autoCapture toggles', () {
    final controller = makeController(const PaperScannerOptions());
    expect(controller.autoCapture, isFalse);
    controller.toggleAutoCapture();
    expect(controller.autoCapture, isTrue);
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
}
