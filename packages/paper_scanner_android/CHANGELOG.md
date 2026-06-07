## 0.1.1

* Retargets the federated implementation to `paper_document_scanner`.

## 0.1.0

* Initial release.
* OpenCV-backed `detectInImage`, `detectInFrame`, `cropPerspective`,
  `applyFilter`.
* Bundles `org.opencv:opencv:4.10.0`; `minSdk 21`.
* EXIF-aware upright decoding so detection and crop share the same pixels.
