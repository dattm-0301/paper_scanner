import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScanPoint', () {
    test('clamped constrains both axes to the unit square', () {
      expect(const ScanPoint(-0.5, 1.5).clamped, const ScanPoint(0, 1));
    });

    test('translate offsets both axes', () {
      final p = const ScanPoint(0.2, 0.3).translate(0.1, -0.1);
      expect(p.x, closeTo(0.3, 1e-9));
      expect(p.y, closeTo(0.2, 1e-9));
    });

    test('round-trips through Offset', () {
      const p = ScanPoint(0.25, 0.75);
      expect(p.toOffset(), const Offset(0.25, 0.75));
      expect(ScanPoint.fromOffset(p.toOffset()), p);
    });

    test('equality and hashCode are value-based', () {
      expect(const ScanPoint(0.1, 0.2), const ScanPoint(0.1, 0.2));
      expect(
        const ScanPoint(0.1, 0.2).hashCode,
        const ScanPoint(0.1, 0.2).hashCode,
      );
      expect(const ScanPoint(0.1, 0.2), isNot(const ScanPoint(0.2, 0.1)));
    });
  });

  group('DetectedQuad', () {
    test('fromMap parses corners and confidence', () {
      final dq = DetectedQuad.fromMap(const {
        'corners': [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0],
        'confidence': 0.42,
      });
      expect(dq.quad, Quad.full());
      expect(dq.confidence, 0.42);
    });

    test('fromMap defaults confidence to 0 when absent', () {
      final dq = DetectedQuad.fromMap(const {
        'corners': [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0],
      });
      expect(dq.confidence, 0);
    });

    test('toMap serializes corners and confidence', () {
      final map = DetectedQuad(quad: Quad.full(), confidence: 0.5).toMap();
      expect(map['corners'], [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0]);
      expect(map['confidence'], 0.5);
    });
  });

  group('FrameData', () {
    test('toMap serializes fields and the wire format name', () {
      final frame = FrameData(
        bytes: Uint8List.fromList(const [1, 2, 3]),
        width: 640,
        height: 480,
        bytesPerRow: 640,
        rotation: 90,
        format: FrameFormat.bgra8888,
      );
      final map = frame.toMap();

      expect(map['width'], 640);
      expect(map['height'], 480);
      expect(map['bytesPerRow'], 640);
      expect(map['rotation'], 90);
      expect(map['format'], 'bgra8888');
      expect(map['bytes'], isA<Uint8List>());
    });
  });

  group('wire names', () {
    test('ScanFilter wire names are stable', () {
      expect(ScanFilter.original.wireName, 'original');
      expect(ScanFilter.enhance.wireName, 'enhance');
      expect(ScanFilter.grayscale.wireName, 'grayscale');
      expect(ScanFilter.blackWhite.wireName, 'blackWhite');
    });

    test('FrameFormat wire names are stable', () {
      expect(FrameFormat.yuv420.wireName, 'yuv420');
      expect(FrameFormat.bgra8888.wireName, 'bgra8888');
    });
  });

  group('MethodChannelPaperScanner.detectInFrame', () {
    final platform = MethodChannelPaperScanner();
    const channel = MethodChannel('paper_scanner');

    FrameData frame() => FrameData(
          bytes: Uint8List(0),
          width: 2,
          height: 2,
          bytesPerRow: 2,
          rotation: 0,
          format: FrameFormat.yuv420,
        );

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('parses the channel response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'detectInFrame');
        return <String, Object?>{
          'corners': <double>[0, 0, 1, 0, 1, 1, 0, 1],
          'confidence': 0.6,
        };
      });

      final dq = await platform.detectInFrame(frame());
      expect(dq, isNotNull);
      expect(dq!.confidence, 0.6);
      expect(dq.quad, Quad.full());
    });

    test('returns null when the channel yields null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);

      expect(await platform.detectInFrame(frame()), isNull);
    });
  });
}
