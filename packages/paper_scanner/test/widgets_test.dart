import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_scanner/paper_scanner.dart';
import 'package:paper_scanner/src/ui/filter_view.dart';
import 'package:paper_scanner/src/ui/page_thumbnails.dart';
import 'package:paper_scanner/src/ui/scanner_chrome.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

/// A valid 1x1 PNG so `Image.file` widgets resolve without decode errors.
const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC';

/// Fake platform whose crop step returns a real, on-disk file path so the
/// review sheet's thumbnails load deterministically.
class _RealFileFake extends PaperScannerPlatform {
  _RealFileFake(this.croppedPath);

  final String croppedPath;

  @override
  Future<DetectedQuad?> detectInImage(String path) async =>
      DetectedQuad(quad: Quad.full(), confidence: 1);

  @override
  Future<String> cropPerspective(String path, Quad quad) async => croppedPath;

  @override
  Future<String> applyFilter(String path, ScanFilter filter) async => path;
}

void main() {
  group('FilterPickerSheet', () {
    testWidgets('renders every filter and updates the session filter on tap',
        (tester) async {
      final controller =
          PaperScannerController(options: const PaperScannerOptions());
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterPickerSheet(
              controller: controller,
              style: const PaperScannerStyle(),
            ),
          ),
        ),
      );

      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Enhance'), findsOneWidget);
      expect(find.text('Grayscale'), findsOneWidget);
      expect(find.text('B & W'), findsOneWidget);
      expect(controller.sessionFilter, ScanFilter.original);

      await tester.tap(find.text('Grayscale'));
      await tester.pump();

      expect(controller.sessionFilter, ScanFilter.grayscale);
    });
  });

  group('ScannerTopBar', () {
    testWidgets('shows the title and reports back taps', (tester) async {
      var backTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScannerTopBar(
              title: 'Adjust corners',
              style: const PaperScannerStyle(),
              onBack: () => backTaps++,
            ),
          ),
        ),
      );

      expect(find.text('Adjust corners'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(backTaps, 1);
    });
  });

  group('ScannerBottomActionBar', () {
    Widget host({
      required bool busy,
      required VoidCallback onPrimary,
      required VoidCallback onSecondary,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: ScannerBottomActionBar(
            style: const PaperScannerStyle(),
            primaryLabel: 'Keep',
            onPrimary: onPrimary,
            secondaryLabel: 'Retake',
            onSecondary: onSecondary,
            busy: busy,
          ),
        ),
      );
    }

    testWidgets('fires primary and secondary callbacks', (tester) async {
      var primary = 0;
      var secondary = 0;
      await tester.pumpWidget(host(
        busy: false,
        onPrimary: () => primary++,
        onSecondary: () => secondary++,
      ));

      await tester.tap(find.text('Keep'));
      await tester.tap(find.text('Retake'));
      expect(primary, 1);
      expect(secondary, 1);
    });

    testWidgets('shows a spinner and disables the secondary action when busy',
        (tester) async {
      var secondary = 0;
      await tester.pumpWidget(host(
        busy: true,
        onPrimary: () {},
        onSecondary: () => secondary++,
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Keep'), findsNothing); // replaced by the spinner

      await tester.tap(find.text('Retake'));
      expect(secondary, 0); // disabled while busy
    });
  });

  group('PageThumbnailStrip', () {
    testWidgets('renders nothing when there are no pages', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PageThumbnailStrip(pages: [], style: PaperScannerStyle()),
          ),
        ),
      );
      expect(find.byType(Image), findsNothing);
    });
  });

  group('PageReviewSheet', () {
    testWidgets('lists committed pages and deletes one on tap', (tester) async {
      final dir = await Directory.systemTemp.createTemp('paper_scanner_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final imgPath = '${dir.path}/page.png';
      File(imgPath).writeAsBytesSync(base64Decode(_png1x1));

      final controller = PaperScannerController(
        options: const PaperScannerOptions(),
        platform: _RealFileFake(imgPath),
      );
      addTearDown(controller.dispose);

      await controller.onCaptured('a.jpg');
      await controller.keepDraft();
      await controller.onCaptured('b.jpg');
      await controller.keepDraft();
      expect(controller.pageCount, 2);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageReviewSheet(
              controller: controller,
              style: const PaperScannerStyle(),
            ),
          ),
        ),
      );
      // Let the real file-backed images resolve cleanly.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();

      expect(controller.pageCount, 1);
    });
  });

  group('PaperScannerScreen', () {
    testWidgets('falls back to the permission view when no camera is available',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PaperScannerScreen()));
      await tester.pumpAndSettle();

      // No camera plugin is registered under the test binding, so the screen
      // resolves to its permission-denied state.
      expect(find.text('Camera access needed'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
