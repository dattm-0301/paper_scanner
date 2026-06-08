import 'package:flutter/foundation.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

import 'logging.dart';
import 'paper_scan_result.dart';
import 'paper_scanner_options.dart';
import 'pdf_builder.dart';

/// The stages a scan session moves through.
enum ScanStage {
  /// Camera is being initialized / permission requested.
  initializing,

  /// Camera permission was denied; show the permission prompt.
  permissionDenied,

  /// Live camera preview with realtime edge overlay.
  camera,

  /// Reviewing a capture with draggable crop corners (Retake / Keep).
  crop,

  /// Assembling the final result (and PDF).
  processing,

  /// Session finished; result delivered.
  finished,
}

/// Drives the entire scan flow with a plain [ChangeNotifier] — **no
/// bloc/flutter_bloc dependency**, deliberately, so this package never
/// version-locks a consumer's state-management choice.
///
/// The UI ([PaperScannerScreen]) is a thin, rebuild-on-notify view over this
/// controller; all platform calls (`detect*`, `cropPerspective`, `applyFilter`)
/// are funneled through here.
class PaperScannerController extends ChangeNotifier {
  PaperScannerController({
    required this.options,
    PaperScannerPlatform? platform,
    PdfAssembler pdfAssembler = buildPdf,
  }) : _platform = platform ?? PaperScannerPlatform.instance,
       _pdfAssembler = pdfAssembler {
    _sessionFilter = options.initialFilter;
    _autoCapture = options.autoCapture;
  }

  /// Behavioral options for this session.
  final PaperScannerOptions options;

  final PaperScannerPlatform _platform;
  final PdfAssembler _pdfAssembler;

  // --- state --------------------------------------------------------------

  ScanStage _stage = ScanStage.initializing;
  ScanStage get stage => _stage;

  final List<ScannedPage> _pages = <ScannedPage>[];

  /// Committed pages, in order.
  List<ScannedPage> get pages => List<ScannedPage>.unmodifiable(_pages);

  /// The page being captured/cropped/filtered but not yet committed.
  ScannedPage? _draft;
  ScannedPage? get draft => _draft;

  /// Latest realtime detection for the live overlay (null when none).
  DetectedQuad? _liveQuad;
  DetectedQuad? get liveQuad => _liveQuad;

  bool _busy = false;

  /// True while a native operation (detect/crop/filter) is running.
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  bool _liveDetectInFlight = false;
  bool _disposed = false;

  /// Whether another page can still be added.
  bool get canAddMore =>
      options.maxPages <= 0 || _pages.length < options.maxPages;

  /// Whether enough pages exist to finish the scan session.
  bool get canFinish => _pages.isNotEmpty && _pages.length >= options.minPages;

  /// Total committed pages.
  int get pageCount => _pages.length;

  /// Filter applied to each kept page, selectable via the camera "Filters"
  /// control. Initialized from [PaperScannerOptions.initialFilter].
  ScanFilter _sessionFilter = ScanFilter.original;
  ScanFilter get sessionFilter => _sessionFilter;

  /// Sets the session filter (affects subsequently kept pages).
  void setSessionFilter(ScanFilter filter) {
    if (_sessionFilter == filter) return;
    _sessionFilter = filter;
    notifyListeners();
  }

  /// Whether auto-capture is enabled (capture when a stable quad is detected).
  /// Initialized from [PaperScannerOptions.autoCapture] (on by default).
  bool _autoCapture = true;
  bool get autoCapture => _autoCapture;

  /// Toggles auto-capture mode.
  void toggleAutoCapture() {
    _autoCapture = !_autoCapture;
    notifyListeners();
  }

  // --- camera lifecycle ---------------------------------------------------

  /// Called by the camera view once the preview is live.
  void markCameraReady() => _setStage(ScanStage.camera);

  /// Called by the camera view when permission is unavailable.
  void markPermissionDenied() => _setStage(ScanStage.permissionDenied);

  /// Re-enter the camera stage (e.g. after a permission retry).
  void retryCamera() => _setStage(ScanStage.initializing);

  // --- realtime detection -------------------------------------------------

  /// Runs realtime detection on a downscaled preview [frame].
  ///
  /// Frames are dropped while a previous detection is in flight, so a slow
  /// device simply detects less often instead of queuing work.
  Future<void> detectLive(FrameData frame) async {
    if (_disposed || !options.enableLiveDetection || _liveDetectInFlight) {
      return;
    }
    _liveDetectInFlight = true;
    try {
      final result = await _platform.detectInFrame(frame);
      if (_disposed) return;
      _liveQuad = result;
      notifyListeners();
    } catch (e) {
      // Transient preview detection failures are non-fatal.
      scannerLog('detectLive failed: $e');
    } finally {
      _liveDetectInFlight = false;
    }
  }

  // --- capture / crop / keep ---------------------------------------------

  /// Handles a freshly captured still at [path].
  ///
  /// Runs still detection to place the crop corners, then:
  ///
  /// * if [PaperScannerOptions.confirmAfterCapture] is set, pauses on the crop
  ///   stage so the user can Retake / Keep (the legacy flow); otherwise
  /// * commits the page immediately with the detected crop and the active
  ///   session filter (the default, native-like flow) and returns to the
  ///   camera. Corrections happen later in the detail/edit view.
  Future<void> onCaptured(String path) async {
    _liveQuad = null;
    _error = null;
    final draft = ScannedPage(originalPath: path, quad: Quad.full());
    _draft = draft;
    _setBusy(true);
    if (options.confirmAfterCapture) _setStage(ScanStage.crop);

    try {
      final detected = await _platform.detectInImage(path);
      draft.quad = detected?.quad ?? Quad.full();
    } catch (e) {
      scannerLog('detectInImage failed: $e');
      draft.quad = Quad.full();
    }

    if (options.confirmAfterCapture) {
      _setBusy(false);
      return;
    }

    // Seamless auto-keep: crop + filter + commit, then back to the camera.
    try {
      draft.croppedPath = await _platform.cropPerspective(
        draft.originalPath,
        (draft.quad ?? Quad.full()).clamped,
      );
      draft.filter = _sessionFilter;
      draft.filteredPath = _sessionFilter == ScanFilter.original
          ? null
          : await _platform.applyFilter(draft.croppedPath!, _sessionFilter);
      _commitDraft();
    } catch (e) {
      _error = '$e';
      scannerLog('onCaptured auto-keep failed: $e');
      _draft = null;
    } finally {
      _setBusy(false);
      _setStage(ScanStage.camera);
    }
  }

  /// Updates the draft page's crop quad (from corner dragging).
  void updateDraftQuad(Quad quad) {
    final draft = _draft;
    if (draft == null) return;
    draft.quad = quad;
    notifyListeners();
  }

  /// "Keep": perspective-crops the draft, applies the active [sessionFilter],
  /// commits the page, and returns to the camera for the next scan.
  Future<void> keepDraft() async {
    final draft = _draft;
    if (draft == null) return;
    _setBusy(true);
    _error = null;
    try {
      final cropped = await _platform.cropPerspective(
        draft.originalPath,
        (draft.quad ?? Quad.full()).clamped,
      );
      draft.croppedPath = cropped;
      draft.filter = _sessionFilter;
      draft.filteredPath = _sessionFilter == ScanFilter.original
          ? null
          : await _platform.applyFilter(cropped, _sessionFilter);
      _commitDraft();
      _setStage(ScanStage.camera);
    } catch (e) {
      _error = '$e';
      scannerLog('keepDraft failed: $e');
    } finally {
      _setBusy(false);
    }
  }

  /// Discards the current draft and returns to the camera.
  void retakeDraft() {
    _draft = null;
    _setStage(ScanStage.camera);
  }

  /// Commits the draft page to [pages].
  void _commitDraft() {
    final draft = _draft;
    if (draft == null) return;
    _pages.add(draft);
    _draft = null;
  }

  // --- per-page edits (detail / edit view) --------------------------------

  ScannedPage? _pageAt(int index) =>
      (index < 0 || index >= _pages.length) ? null : _pages[index];

  /// Re-applies the perspective crop on the committed page at [index] using a
  /// new [quad] (from the detail-view re-crop tool), then re-applies its filter
  /// and rotation on top.
  Future<void> recropPage(int index, Quad quad) async {
    final page = _pageAt(index);
    if (page == null) return;
    page.quad = quad;
    await _rebuildPage(
      page,
      cropDirty: true,
      filterDirty: false,
      rotationDirty: false,
    );
  }

  /// Changes the [filter] of the committed page at [index] (detail-view filter
  /// tool), re-deriving the filtered image and re-applying rotation.
  Future<void> setPageFilter(int index, ScanFilter filter) async {
    final page = _pageAt(index);
    if (page == null || page.filter == filter) return;
    page.filter = filter;
    await _rebuildPage(
      page,
      cropDirty: false,
      filterDirty: true,
      rotationDirty: false,
    );
  }

  /// Rotates the committed page at [index] clockwise by [by] quarter turns
  /// (detail-view rotate tool). Only the (cheap) rotation step is re-run.
  Future<void> rotatePage(int index, {int by = 1}) async {
    final page = _pageAt(index);
    if (page == null) return;
    page.rotationTurns = (page.rotationTurns + by) % 4;
    await _rebuildPage(
      page,
      cropDirty: false,
      filterDirty: false,
      rotationDirty: true,
    );
  }

  /// Recomputes a page's derived images. Each dirty step cascades into the
  /// next (a new crop invalidates the filter, a new filter invalidates the
  /// rotation), so editing a corner correctly re-runs filter + rotation.
  Future<void> _rebuildPage(
    ScannedPage page, {
    required bool cropDirty,
    required bool filterDirty,
    required bool rotationDirty,
  }) async {
    _setBusy(true);
    _error = null;
    try {
      if (cropDirty || page.croppedPath == null) {
        page.croppedPath = await _platform.cropPerspective(
          page.originalPath,
          (page.quad ?? Quad.full()).clamped,
        );
        filterDirty = true;
      }
      if (filterDirty) {
        page.filteredPath = page.filter == ScanFilter.original
            ? null
            : await _platform.applyFilter(page.croppedPath!, page.filter);
        rotationDirty = true;
      }
      if (rotationDirty) {
        page.rotatedPath = page.rotationTurns % 4 == 0
            ? null
            : await _platform.rotate(page.processedPath, page.rotationTurns);
      }
    } catch (e) {
      _error = '$e';
      scannerLog('rebuildPage failed: $e');
    } finally {
      _setBusy(false);
    }
  }

  // --- multi-page editing -------------------------------------------------

  /// Removes the committed page at [index].
  void deletePage(int index) {
    if (index < 0 || index >= _pages.length) return;
    _pages.removeAt(index);
    notifyListeners();
  }

  /// Reorders committed pages (as in a [ReorderableListView]).
  void reorderPages(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _pages.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    final page = _pages.removeAt(oldIndex);
    _pages.insert(target.clamp(0, _pages.length), page);
    notifyListeners();
  }

  // --- finish -------------------------------------------------------------

  /// Commits the draft (if any) and produces the final [PaperScanResult],
  /// assembling a PDF when [PaperScannerOptions.outputPdf] is set.
  Future<PaperScanResult> finish() async {
    _commitDraft();
    _setStage(ScanStage.processing);
    final pageResults = _pages
        .map(
          (p) => ScannedPageResult(
            path: p.outputPath,
            originalPath: p.originalPath,
            filter: p.filter,
            rotationTurns: p.rotationTurns,
            quad: p.quad,
          ),
        )
        .toList(growable: false);
    final paths = pageResults.map((p) => p.path).toList(growable: false);
    String? pdfPath;
    if (options.outputPdf && paths.isNotEmpty) {
      try {
        pdfPath = await _pdfAssembler(paths);
      } catch (e) {
        scannerLog('buildPdf failed: $e');
        rethrow;
      }
    }
    _setStage(ScanStage.finished);
    return PaperScanResult(
      imagePaths: paths,
      pdfPath: pdfPath,
      pages: pageResults,
    );
  }

  // --- internals ----------------------------------------------------------

  void _setStage(ScanStage stage) {
    if (_disposed) return;
    _stage = stage;
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_disposed) return;
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
