# paper_scanner_android

The Android implementation of [`paper_scanner`][app], using **OpenCV**.

Apps should depend on `paper_scanner` (this package is pulled in automatically
as the endorsed Android implementation).

## How it works

| Operation | OpenCV pipeline |
|-----------|-----------------|
| Detect | `cvtColor → GaussianBlur → Canny → dilate → findContours → approxPolyDP` → largest convex 4-point quad |
| Crop | `getPerspectiveTransform → warpPerspective` |
| Filter | `cvtColor` (grayscale), `adaptiveThreshold` (black-and-white), CLAHE on Lab L-channel (enhance) |

Realtime frames send only the **Y/luminance plane** (or BGRA on the rare
Android BGRA stream), which is all edge detection needs, keeping the channel
cheap.

## Why OpenCV and not ML Kit?

ML Kit exposes **no standalone document-quad detector** — detection is locked
inside the full-UI `GmsDocumentScanner`, whose camera/crop/review flow is
rendered by Google Play services and cannot be restyled. To build a custom UI
we need detection-only primitives, so this package uses OpenCV.

## Native dependency

```gradle
implementation "org.opencv:opencv:4.10.0"
```

OpenCV bundles prebuilt `.so` libraries per ABI (`arm64-v8a`, `armeabi-v7a`,
`x86`, `x86_64`) — roughly **10 MB per ABI**. Use ABI splits or an app bundle
to avoid shipping all four to every device. `minSdk 21`.

[app]: https://pub.dev/packages/paper_scanner
