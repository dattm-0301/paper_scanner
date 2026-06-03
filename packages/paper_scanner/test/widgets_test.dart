import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart'
    as camera_platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_scanner/paper_scanner.dart';
import 'package:paper_scanner/src/ui/camera_view.dart';
import 'package:paper_scanner/src/ui/crop_view.dart';
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

class _CameraActionFake extends PaperScannerPlatform {
  String? detectedPath;

  @override
  Future<DetectedQuad?> detectInImage(String path) async {
    detectedPath = path;
    return DetectedQuad(quad: Quad.full(), confidence: 1);
  }
}

class _FakeCameraPlatform extends camera_platform.CameraPlatform {
  final List<camera_platform.FlashMode> flashModes =
      <camera_platform.FlashMode>[];
  int takePictureCount = 0;

  @override
  Future<List<camera_platform.CameraDescription>> availableCameras() async =>
      <camera_platform.CameraDescription>[
        const camera_platform.CameraDescription(
          name: 'back',
          lensDirection: camera_platform.CameraLensDirection.back,
          sensorOrientation: 90,
        ),
      ];

  @override
  Future<int> createCamera(
    camera_platform.CameraDescription cameraDescription,
    camera_platform.ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async => 7;

  @override
  Future<int> createCameraWithSettings(
    camera_platform.CameraDescription cameraDescription,
    camera_platform.MediaSettings mediaSettings,
  ) async => 7;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    camera_platform.ImageFormatGroup imageFormatGroup =
        camera_platform.ImageFormatGroup.unknown,
  }) async {}

  @override
  Stream<camera_platform.CameraInitializedEvent> onCameraInitialized(
    int cameraId,
  ) => Stream<camera_platform.CameraInitializedEvent>.value(
    camera_platform.CameraInitializedEvent(
      cameraId,
      1080,
      1920,
      camera_platform.ExposureMode.auto,
      true,
      camera_platform.FocusMode.auto,
      true,
    ),
  );

  @override
  Stream<camera_platform.CameraClosingEvent> onCameraClosing(int cameraId) =>
      const Stream<camera_platform.CameraClosingEvent>.empty();

  @override
  Stream<camera_platform.CameraErrorEvent> onCameraError(int cameraId) =>
      Stream<camera_platform.CameraErrorEvent>.value(
        camera_platform.CameraErrorEvent(cameraId, 'test error'),
      );

  @override
  Stream<camera_platform.DeviceOrientationChangedEvent>
  onDeviceOrientationChanged() =>
      Stream<camera_platform.DeviceOrientationChangedEvent>.value(
        const camera_platform.DeviceOrientationChangedEvent(
          DeviceOrientation.portraitUp,
        ),
      );

  @override
  Widget buildPreview(int cameraId) =>
      const ColoredBox(color: Colors.black, child: SizedBox.expand());

  @override
  Future<void> setFlashMode(
    int cameraId,
    camera_platform.FlashMode mode,
  ) async {
    flashModes.add(mode);
  }

  @override
  Future<camera_platform.XFile> takePicture(int cameraId) async {
    takePictureCount++;
    return camera_platform.XFile('/tmp/paper_scanner_capture.jpg');
  }

  @override
  Future<void> dispose(int cameraId) async {}
}

class _NoCameraPlatform extends camera_platform.CameraPlatform {
  @override
  Future<List<camera_platform.CameraDescription>> availableCameras() async =>
      <camera_platform.CameraDescription>[];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void useDeviceLocale(WidgetTester tester, Locale locale) {
    tester.binding.platformDispatcher.localeTestValue = locale;
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
  }

  group('FilterPickerSheet', () {
    test('labels default to German and resolve supported locales', () {
      const labels = PaperScannerLabels();

      expect(labels.readyForNextScan, 'Bereit für den nächsten Scan.');
      expect(labels.filterEnhance, 'Verbessern');
      expect(
        labels.resolve(const Locale('fr')).cameraPermissionTitle,
        'Kamerazugriff erforderlich',
      );
      expect(
        labels.resolve(const Locale('de')).retryCamera,
        'Erneut versuchen',
      );
      expect(labels.resolve(const Locale('en')).retryCamera, 'Try again');
      expect(labels.resolve(const Locale('vi')).retryCamera, 'Thử lại');
    });

    testWidgets('renders every filter and updates the session filter on tap', (
      tester,
    ) async {
      final controller = PaperScannerController(
        options: const PaperScannerOptions(),
      );
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

    testWidgets('uses Vietnamese labels from the device locale', (
      tester,
    ) async {
      useDeviceLocale(tester, const Locale('vi'));

      final controller = PaperScannerController(
        options: const PaperScannerOptions(),
      );
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

      expect(find.text('Bộ lọc'), findsOneWidget);
      expect(find.text('Gốc'), findsOneWidget);
      expect(find.text('Nâng cao'), findsOneWidget);
      expect(find.text('Xám'), findsOneWidget);
      expect(find.text('Đen trắng'), findsOneWidget);
    });

    testWidgets('uses German labels from the device locale', (tester) async {
      useDeviceLocale(tester, const Locale('de'));

      final controller = PaperScannerController(
        options: const PaperScannerOptions(),
      );
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

      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Verbessern'), findsOneWidget);
      expect(find.text('Graustufen'), findsOneWidget);
      expect(find.text('S/W'), findsOneWidget);
    });
  });

  group('CameraView', () {
    late camera_platform.CameraPlatform previousCameraPlatform;
    late _FakeCameraPlatform cameraPlatform;

    setUp(() {
      previousCameraPlatform = camera_platform.CameraPlatform.instance;
      cameraPlatform = _FakeCameraPlatform();
      camera_platform.CameraPlatform.instance = cameraPlatform;
    });

    tearDown(() {
      camera_platform.CameraPlatform.instance = previousCameraPlatform;
    });

    Future<void> pumpCameraView(
      WidgetTester tester,
      PaperScannerController controller,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraView(
              controller: controller,
              style: const PaperScannerStyle(),
              onDone: () {},
              onReview: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('flash, filters, auto-shutter, and capture controls work', (
      tester,
    ) async {
      final scannerPlatform = _CameraActionFake();
      final controller = PaperScannerController(
        options: const PaperScannerOptions(enableLiveDetection: false),
        platform: scannerPlatform,
      );
      addTearDown(controller.dispose);

      await pumpCameraView(tester, controller);

      await tester.tap(find.byKey(const Key('paper_scanner_flash_control')));
      await tester.pumpAndSettle();
      expect(cameraPlatform.flashModes, <camera_platform.FlashMode>[
        camera_platform.FlashMode.auto,
      ]);

      await tester.tap(find.byKey(const Key('paper_scanner_filters_control')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grayscale'));
      await tester.pump();
      expect(controller.sessionFilter, ScanFilter.grayscale);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('paper_scanner_auto_shutter_control')),
      );
      await tester.pump();
      expect(controller.autoCapture, isTrue);

      await tester.tap(find.byKey(const Key('paper_scanner_capture_button')));
      await tester.pumpAndSettle();
      expect(cameraPlatform.takePictureCount, 1);
      expect(scannerPlatform.detectedPath, '/tmp/paper_scanner_capture.jpg');
      expect(controller.stage, ScanStage.crop);
    });

    testWidgets('positions top chrome with requested offsets', (tester) async {
      useDeviceLocale(tester, const Locale('vi'));

      final dir = Directory.systemTemp.createTempSync('paper_scanner_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final imgPath = '${dir.path}/page.png';
      File(imgPath).writeAsBytesSync(base64Decode(_png1x1));

      final controller = PaperScannerController(
        options: const PaperScannerOptions(enableLiveDetection: false),
        platform: _RealFileFake(imgPath),
      );
      addTearDown(controller.dispose);
      await controller.onCaptured(imgPath);
      await controller.keepDraft();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
            child: Scaffold(
              body: CameraView(
                controller: controller,
                style: const PaperScannerStyle(),
                onDone: () {},
                onReview: () {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sẵn sàng quét tiếp.'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const Key('paper_scanner_ready_status')))
            .dy,
        110,
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('paper_scanner_cancel_button')))
            .dy,
        62,
      );
      expect(
        tester
            .getTopLeft(find.byKey(const Key('paper_scanner_done_button')))
            .dy,
        62,
      );
    });
  });

  group('CropView', () {
    testWidgets('keeps Retake and Keep pills compact at the top', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('paper_scanner_test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final imgPath = '${dir.path}/page.png';
      File(imgPath).writeAsBytesSync(base64Decode(_png1x1));

      final controller = PaperScannerController(
        options: const PaperScannerOptions(),
        platform: _RealFileFake(imgPath),
      );
      addTearDown(controller.dispose);
      await controller.onCaptured(imgPath);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CropView(
              controller: controller,
              style: const PaperScannerStyle(),
              onKeep: () {},
              onRetake: () {},
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      final retakeSize = tester.getSize(
        find.byKey(const Key('paper_scanner_retake_button')),
      );
      final keepSize = tester.getSize(
        find.byKey(const Key('paper_scanner_keep_button')),
      );

      expect(retakeSize.height, lessThan(80));
      expect(keepSize.height, lessThan(80));
      expect(retakeSize.width, lessThan(160));
      expect(keepSize.width, lessThan(160));
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
      await tester.pumpWidget(
        host(
          busy: false,
          onPrimary: () => primary++,
          onSecondary: () => secondary++,
        ),
      );

      await tester.tap(find.text('Keep'));
      await tester.tap(find.text('Retake'));
      expect(primary, 1);
      expect(secondary, 1);
    });

    testWidgets('shows a spinner and disables the secondary action when busy', (
      tester,
    ) async {
      var secondary = 0;
      await tester.pumpWidget(
        host(busy: true, onPrimary: () {}, onSecondary: () => secondary++),
      );

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
      final dir = Directory.systemTemp.createTempSync('paper_scanner_test');
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
    testWidgets(
      'falls back to the permission view when no camera is available',
      (tester) async {
        final previousCameraPlatform = camera_platform.CameraPlatform.instance;
        camera_platform.CameraPlatform.instance = _NoCameraPlatform();
        addTearDown(() {
          camera_platform.CameraPlatform.instance = previousCameraPlatform;
        });

        await tester.pumpWidget(const MaterialApp(home: PaperScannerScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // No camera plugin is registered under the test binding, so the screen
        // resolves to its permission-denied state.
        expect(find.text('Camera access needed'), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
      },
    );

    testWidgets('localizes permission text from the device locale', (
      tester,
    ) async {
      useDeviceLocale(tester, const Locale('vi'));

      final previousCameraPlatform = camera_platform.CameraPlatform.instance;
      camera_platform.CameraPlatform.instance = _NoCameraPlatform();
      addTearDown(() {
        camera_platform.CameraPlatform.instance = previousCameraPlatform;
      });

      await tester.pumpWidget(const MaterialApp(home: PaperScannerScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Cần quyền camera'), findsOneWidget);
      expect(
        find.text('Cho phép truy cập camera để quét tài liệu.'),
        findsOneWidget,
      );
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
