# paper_scanner

A **fully custom, themeable** Flutter document scanner — live camera, automatic
edge detection, **auto-capture**, draggable corner crop, filters, rotation,
multi-page, and optional PDF output. Unlike packages that wrap the OS system
scanners (ML Kit Document Scanner on Android, VisionKit
`VNDocumentCameraViewController` on iOS), the entire UI is rendered by Flutter
widgets you can restyle and localize — yet it **mimics the native look** of
those scanners out of the box.

## Capture & edit flow

- **Auto-capture (default on):** the shutter fires automatically once a
  confident document quad is held steady in frame — no tap required. The manual
  shutter stays available. Toggle via `PaperScannerOptions(autoCapture: …)`; set
  `confirmAfterCapture: true` to keep the legacy Retake / Keep step.
- **Tap a page preview → full-screen detail view.** There each page can be
  **re-cropped** (drag the corners again on the original capture, with a
  magnifier loupe), **rotated** in 90° steps, **re-filtered** per page, or
  deleted — the same toolset the OS scanners expose.
- **Adaptive look:** `PaperScannerStyle.skin` (`ScannerSkin.adaptive` by
  default) renders a VisionKit-style layout on iOS and an ML Kit-style layout on
  Android; force either with `ScannerSkin.ios` / `ScannerSkin.android`.

## Why not just wrap the system scanner?

The OS scanners render their UI **inside the operating system** and expose **no
public API to customize** colors, buttons, or layout:

- **Android — ML Kit Document Scanner:** the docs state the capture/edit/review
  "user flow … is provided by the SDK." There is no standalone document-quad
  detector and no UI hooks.
- **iOS — VisionKit `VNDocumentCameraViewController`:** exposes only a results
  delegate; the camera/crop UI lives in private `ICDocCam*` classes.

So `paper_scanner` uses **detection-only** platform APIs and builds its own UI:

| Layer | iOS | Android |
|-------|-----|---------|
| Edge / quad detection | `Vision` (`VNDetectDocumentSegmentationRequest`, fallback `VNDetectRectanglesRequest`) | OpenCV (`Canny` → `findContours` → `approxPolyDP`) |
| Perspective crop | CoreImage `CIPerspectiveCorrection` | OpenCV `warpPerspective` |
| Filters | `CIColorControls` / `CIPhotoEffectMono` / threshold | `cvtColor` / `adaptiveThreshold` / CLAHE |
| Rotation | CoreImage affine transform | `Bitmap` + `Matrix.postRotate` |

## Monorepo layout (federated plugin)

```
packages/
  paper_scanner/                      app-facing: shared Dart UI + controller + models + styles
  paper_scanner_platform_interface/   abstract API + method-channel contract (Pigeon-ready)
  paper_scanner_android/              Kotlin + OpenCV
  paper_scanner_ios/                  Swift + Vision + CoreImage
example/                              demo app
```

## Quick start

```dart
final result = await PaperScanner.open(
  context,
  options: const PaperScannerOptions(outputPdf: true),
  style: PaperScannerStyle(/* colors, labels, slot builders */),
);
if (result != null) {
  print(result.imagePaths); // cropped + filtered page images
  print(result.pdfPath);    // assembled PDF (when outputPdf: true)
}
```

Add the camera usage strings: `NSCameraUsageDescription` (iOS `Info.plist`) and
the `CAMERA` permission (Android `AndroidManifest.xml`).

## Development

```bash
dart pub global activate melos
melos bootstrap     # link packages + example
melos run analyze
melos run test
```

Publish order: `paper_scanner_platform_interface` → `paper_scanner_android` &
`paper_scanner_ios` → `paper_scanner`.

> **Pigeon migration.** The typed channel contract lives in
> `packages/paper_scanner_platform_interface/pigeons/messages.dart`. The
> shipping implementation uses a hand-authored `MethodChannel` (self-consistent
> across Dart/Kotlin/Swift). Running `dart run pigeon` regenerates the typed
> wrappers — see that package's README.

Licensed under MIT.
