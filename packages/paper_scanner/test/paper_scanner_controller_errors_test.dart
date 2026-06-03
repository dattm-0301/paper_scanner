import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper_scanner/paper_scanner.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

/// Configurable fake platform used to exercise the controller's error and
/// edge-case handling.
class _Fake extends PaperScannerPlatform {
  _Fake({this.failCrop = false, this.failDetectImage = false});

  final bool failCrop;
  final bool failDetectImage;

  @override
  Future<DetectedQuad?> detectInImage(String path) async {
    if (failDetectImage) throw Exception('detect boom');
    return DetectedQuad(quad: Quad.full(), confidence: 0.9);
  }

  @override
  Future<DetectedQuad?> detectInFrame(FrameData frame) async => const DetectedQuad(
        quad: Quad(
          topLeft: ScanPoint(0.1, 0.1),
          topRight: ScanPoint(0.9, 0.1),
          bottomRight: ScanPoint(0.9, 0.9),
          bottomLeft: ScanPoint(0.1, 0.9),
        ),
        confidence: 0.7,
      );

  @override
  Future<String> cropPerspective(String path, Quad quad) async {
    if (failCrop) throw Exception('crop boom');
    return '$path.cropped';
  }

  @override
  Future<String> applyFilter(String path, ScanFilter filter) async =>
      filter == ScanFilter.original ? path : '$path.${filter.wireName}';
}

FrameData _frame() => FrameData(
      bytes: Uint8List(0),
      width: 4,
      height: 4,
      bytesPerRow: 4,
      rotation: 0,
      format: FrameFormat.yuv420,
    );

void main() {
  test('onCaptured falls back to a full quad when still detection throws',
      () async {
    final c = PaperScannerController(
      options: const PaperScannerOptions(),
      platform: _Fake(failDetectImage: true),
    );
    addTearDown(c.dispose);

    await c.onCaptured('/p.jpg');

    expect(c.stage, ScanStage.crop);
    expect(c.draft, isNotNull);
    expect(c.draft!.quad, Quad.full());
    expect(c.busy, isFalse);
  });

  test('keepDraft records an error and keeps the draft when crop fails',
      () async {
    final c = PaperScannerController(
      options: const PaperScannerOptions(),
      platform: _Fake(failCrop: true),
    );
    addTearDown(c.dispose);

    await c.onCaptured('/p.jpg');
    await c.keepDraft();

    expect(c.error, isNotNull);
    expect(c.pageCount, 0);
    expect(c.draft, isNotNull); // not committed
    expect(c.stage, ScanStage.crop);
    expect(c.busy, isFalse);
  });

  test('finish rethrows when PDF assembly fails', () async {
    final c = PaperScannerController(
      options: const PaperScannerOptions(outputPdf: true),
      platform: _Fake(),
      pdfAssembler: (paths) async => throw Exception('pdf boom'),
    );
    addTearDown(c.dispose);

    await c.onCaptured('/p.jpg');
    await c.keepDraft();
    expect(c.pageCount, 1);

    await expectLater(c.finish(), throwsA(isA<Exception>()));
  });

  test('detectLive updates liveQuad when live detection is enabled', () async {
    final c = PaperScannerController(
      options: const PaperScannerOptions(),
      platform: _Fake(),
    );
    addTearDown(c.dispose);

    expect(c.liveQuad, isNull);
    await c.detectLive(_frame());

    expect(c.liveQuad, isNotNull);
    expect(c.liveQuad!.confidence, closeTo(0.7, 1e-9));
  });

  test('detectLive is a no-op when live detection is disabled', () async {
    final c = PaperScannerController(
      options: const PaperScannerOptions(enableLiveDetection: false),
      platform: _Fake(),
    );
    addTearDown(c.dispose);

    await c.detectLive(_frame());
    expect(c.liveQuad, isNull);
  });

  test('updateDraftQuad is a no-op without a draft', () {
    final c = PaperScannerController(
      options: const PaperScannerOptions(),
      platform: _Fake(),
    );
    addTearDown(c.dispose);

    expect(() => c.updateDraftQuad(Quad.full()), returnsNormally);
  });

  test('deletePage and reorderPages ignore out-of-range indices', () async {
    final c = PaperScannerController(
      options: const PaperScannerOptions(),
      platform: _Fake(),
    );
    addTearDown(c.dispose);

    await c.onCaptured('/p.jpg');
    await c.keepDraft();
    expect(c.pageCount, 1);

    c.deletePage(5);
    c.deletePage(-1);
    c.reorderPages(9, 0);
    expect(c.pageCount, 1);
  });

  test('setSessionFilter notifies listeners only when the value changes', () {
    final c = PaperScannerController(
      options: const PaperScannerOptions(),
      platform: _Fake(),
    );
    addTearDown(c.dispose);

    var notifications = 0;
    c.addListener(() => notifications++);

    c.setSessionFilter(ScanFilter.original); // same as default → no notify
    expect(notifications, 0);

    c.setSessionFilter(ScanFilter.enhance); // changed → notify
    expect(notifications, 1);
  });

  test('mutating after dispose does not throw', () async {
    final c = PaperScannerController(
      options: const PaperScannerOptions(),
      platform: _Fake(),
    );
    c.dispose();

    expect(c.markCameraReady, returnsNormally);
    await c.detectLive(_frame()); // guarded; must not notify a disposed notifier
    expect(c.liveQuad, isNull);
  });
}
