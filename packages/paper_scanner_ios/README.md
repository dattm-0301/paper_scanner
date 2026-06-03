# paper_scanner_ios

The iOS implementation of [`paper_scanner`][app], using **Apple Vision** and
**CoreImage**.

Apps should depend on `paper_scanner` (this package is pulled in automatically
as the endorsed iOS implementation).

## How it works

| Operation | API |
|-----------|-----|
| Detect | `VNDetectDocumentSegmentationRequest` (iOS 15+), fallback `VNDetectRectanglesRequest` |
| Crop | CoreImage `CIPerspectiveCorrection` |
| Filter | `CIColorControls` (enhance), `CIPhotoEffectMono` (grayscale), `CIColorThreshold`/mono+contrast (black-and-white) |

The document-segmentation request is runtime-gated to iOS 15+ and gracefully
falls back to rectangle detection on older systems. `Vision` coordinates use a
bottom-left origin and are flipped to the top-left origin used across the
plugin.

## Why Vision and not VisionKit?

VisionKit's `VNDocumentCameraViewController` renders its **own** camera, crop
and review UI (private `ICDocCam*` classes) and exposes only a results
delegate — there is no way to restyle it. To build a custom UI we use the
detection-only `Vision` requests instead.

## Requirements

- iOS 13.0+ (`platform :ios, '13.0'`).
- Host app must declare `NSCameraUsageDescription` in `Info.plist`.

[app]: https://pub.dev/packages/paper_scanner
