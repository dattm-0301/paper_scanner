# paper_scanner

A **fully custom, themeable** Flutter document scanner: live camera, automatic
edge detection, draggable corner crop, filters, multi-page, and optional PDF.

Detection runs on **detection-only** native APIs (iOS `Vision`, Android
OpenCV) — there is **no OS system-scanner UI**, so every pixel is yours to
restyle and localize. See the [monorepo README](https://github.com/dattm-0301/paper_scanner)
for why the OS scanners (ML Kit / VisionKit) cannot be themed.

## Install

```yaml
dependencies:
  paper_scanner: ^0.1.0
```

## Usage

```dart
import 'package:paper_scanner/paper_scanner.dart';

final result = await PaperScanner.open(
  context,
  options: const PaperScannerOptions(
    outputPdf: true, // also assemble a PDF
    minPages: 1,     // done button is enabled after this many kept pages
    maxPages: 0,     // 0 = unlimited
  ),
);

if (result != null && !result.isEmpty) {
  print(result.imagePaths); // processed page images, in order
  print(result.pdfPath);    // PDF (when outputPdf: true)
}
```

## Theming & localization

Everything visual lives in `PaperScannerStyle`, including all labels:

```dart
PaperScanner.open(
  context,
  style: PaperScannerStyle(
    accentColor: const Color(0xFF1B998B),
    overlayStrokeWidth: 4,
    cornerHandleRadius: 16,
    labels: const PaperScannerLabels(
      cropTitle: 'Adjust the edges',
      keep: 'Keep',
      done: 'Finish',
    ),
    // Replace individual pieces when you need to:
    captureButtonBuilder: (context, onCapture, busy) => MyShutter(onCapture, busy),
    statusPillBuilder: (context, label, style) => MyStatusPill(label),
    pageThumbnailBuilder: (context, page, onTap, style) =>
        MyThumbnail(page: page, onTap: onTap),
    cornerHandleBuilder: (context) => const MyHandle(),

    // Or replace whole chrome/action regions:
    cameraTopChromeBuilder: (context, controller, style, onCancel, onDone) =>
        MyScannerTopBar(controller, onCancel, onDone),
    cameraBottomChromeBuilder: (
      context,
      controller,
      style,
      onCapture,
      onReview,
      onCycleFlash,
      onOpenFilters,
      onToggleAutoCapture,
      capturing,
      flashIcon,
    ) =>
        MyScannerBottomBar(
          controller: controller,
          onCapture: onCapture,
          onReview: onReview,
          flashIcon: flashIcon,
        ),
    cropActionsBuilder: (context, controller, style, onRetake, onKeep) =>
        MyCropActions(onRetake: onRetake, onKeep: onKeep),
  ),
);
```

State is driven by a plain `PaperScannerController` (a `ChangeNotifier`) — **no
`bloc`/`flutter_bloc` dependency**, so it never version-locks your app.

## Permissions

Add a camera usage description for your platforms:

**iOS** — `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Scan documents with the camera.</string>
```

**Android** — `android/app/src/main/AndroidManifest.xml` (the plugin also
declares it, but keep your own copy explicit):

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

Android `minSdk 21`, iOS `13.0+`. OpenCV adds ~10 MB per ABI — prefer an app
bundle or ABI splits.

## Output

`PaperScanResult { List<String> imagePaths; String? pdfPath; }`. Image paths
point to processed (cropped + filtered) JPEGs in the app cache.
