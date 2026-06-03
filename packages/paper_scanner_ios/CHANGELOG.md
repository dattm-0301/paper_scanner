## 0.1.0

* Initial release.
* Vision-backed `detectInImage` / `detectInFrame`
  (`VNDetectDocumentSegmentationRequest` with `VNDetectRectanglesRequest`
  fallback).
* CoreImage `cropPerspective` (`CIPerspectiveCorrection`) and `applyFilter`
  (enhance / grayscale / black-and-white).
* `platform :ios, '13.0'`; segmentation runtime-gated to iOS 15+.
