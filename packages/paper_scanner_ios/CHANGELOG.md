## 0.1.2

* Add Swift Package Manager (SPM) support — `Package.swift` + Sources layout.

## 0.1.1

* Retargets the federated implementation to `paper_document_scanner`.

## 0.1.0

* Initial release.
* Vision-backed `detectInImage` / `detectInFrame`
  (`VNDetectDocumentSegmentationRequest` with `VNDetectRectanglesRequest`
  fallback).
* CoreImage `cropPerspective` (`CIPerspectiveCorrection`) and `applyFilter`
  (enhance / grayscale / black-and-white).
* `platform :ios, '13.0'`; segmentation runtime-gated to iOS 15+.
