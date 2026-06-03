import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quad', () {
    test('toList/fromList round-trips', () {
      const quad = Quad(
        topLeft: ScanPoint(0.1, 0.2),
        topRight: ScanPoint(0.9, 0.15),
        bottomRight: ScanPoint(0.95, 0.85),
        bottomLeft: ScanPoint(0.05, 0.8),
      );
      expect(Quad.fromList(quad.toList()), quad);
    });

    test('full() covers the whole frame', () {
      expect(Quad.full().toList(), [0, 0, 1, 0, 1, 1, 0, 1]);
    });

    test('clamped constrains corners to the unit square', () {
      const quad = Quad(
        topLeft: ScanPoint(-0.5, 2),
        topRight: ScanPoint(1, 0),
        bottomRight: ScanPoint(1, 1),
        bottomLeft: ScanPoint(0, 1),
      );
      expect(quad.clamped.topLeft, const ScanPoint(0, 1));
    });

    test('copyWithCorner replaces only the indexed corner', () {
      final quad = Quad.full().copyWithCorner(2, const ScanPoint(0.5, 0.5));
      expect(quad.bottomRight, const ScanPoint(0.5, 0.5));
      expect(quad.topLeft, const ScanPoint(0, 0));
    });
  });

  test('default platform instance is the method channel', () {
    expect(PaperScannerPlatform.instance, isA<MethodChannelPaperScanner>());
  });

  group('MethodChannelPaperScanner', () {
    final platform = MethodChannelPaperScanner();
    const channel = MethodChannel('paper_scanner');
    final log = <MethodCall>[];

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        switch (call.method) {
          case 'detectInImage':
          case 'detectInFrame':
            return <String, Object?>{
              'corners': <double>[0, 0, 1, 0, 1, 1, 0, 1],
              'confidence': 0.8,
            };
          case 'cropPerspective':
            return '/tmp/cropped.jpg';
          case 'applyFilter':
            return '/tmp/filtered.jpg';
        }
        return null;
      });
      log.clear();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('detectInImage parses the corner map', () async {
      final quad = await platform.detectInImage('/tmp/in.jpg');
      expect(quad, isNotNull);
      expect(quad!.confidence, 0.8);
      expect(quad.quad, Quad.full());
      expect(log.single.method, 'detectInImage');
      expect((log.single.arguments as Map)['path'], '/tmp/in.jpg');
    });

    test('applyFilter(original) short-circuits without a channel call', () async {
      final out = await platform.applyFilter('/tmp/in.jpg', ScanFilter.original);
      expect(out, '/tmp/in.jpg');
      expect(log, isEmpty);
    });

    test('applyFilter sends the stable wire name', () async {
      await platform.applyFilter('/tmp/in.jpg', ScanFilter.blackWhite);
      expect((log.single.arguments as Map)['filter'], 'blackWhite');
    });

    test('cropPerspective sends exactly 8 corner values', () async {
      final out = await platform.cropPerspective('/tmp/in.jpg', Quad.full());
      expect(out, '/tmp/cropped.jpg');
      expect(((log.single.arguments as Map)['corners'] as List).length, 8);
    });
  });
}
