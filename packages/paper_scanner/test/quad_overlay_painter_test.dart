import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_scanner/src/ui/quad_overlay_painter.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

void main() {
  QuadOverlayPainter painter(
    Quad? quad, {
    Color stroke = const Color(0xFF000000),
    double width = 3,
  }) {
    return QuadOverlayPainter(
      quad: quad,
      strokeColor: stroke,
      fillColor: const Color(0x00000000),
      strokeWidth: width,
    );
  }

  test('shouldRepaint reacts to quad and style changes', () {
    final base = painter(Quad.full());

    expect(base.shouldRepaint(painter(Quad.full())), isFalse);
    expect(base.shouldRepaint(painter(null)), isTrue);
    expect(
      base.shouldRepaint(painter(Quad.full(), stroke: const Color(0xFFFF0000))),
      isTrue,
    );
    expect(base.shouldRepaint(painter(Quad.full(), width: 6)), isTrue);
  });

  test('paint runs for both a null quad and a real quad', () {
    void run(Quad? quad) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter(quad).paint(canvas, const Size(120, 200));
      recorder.endRecording().dispose();
    }

    expect(() => run(null), returnsNormally);
    expect(() => run(Quad.full()), returnsNormally);
  });
}
