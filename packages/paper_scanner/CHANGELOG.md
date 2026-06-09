## 0.1.3

* Update dependencies: `paper_scanner_platform_interface` to `^0.1.1`, `paper_scanner_android` to `^0.1.2`, and `paper_scanner_ios` to `^0.1.3`.
* Update repository visibility to public.

## 0.1.2

* Bump `paper_scanner_ios` dependency to `^0.1.2` (adds Swift Package Manager support).

## 0.1.1

* Fix static analysis lints.
* Add example application.

## 0.1.0

* Initial release.
* `PaperScanner.open` launcher and full-screen `PaperScannerScreen`.
* `PaperScannerController` (`ChangeNotifier`, no bloc dependency) driving
  camera → crop → filter → multi-page → result.
* Live edge-detection overlay, draggable corner crop, filter chips
  (Original / Enhance / Grayscale / B&W), reorderable multi-page strip.
* `PaperScannerStyle` (colors, overlay, handles, labels, widget-builder slots)
  and `PaperScannerOptions` (PDF output, max pages, detection fps).
* Optional PDF assembly via the `pdf` package.
