import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

import '../logging.dart';
import '../paper_scanner_controller.dart';
import '../paper_scanner_style.dart';
import 'filter_view.dart';
import 'quad_overlay_painter.dart';

/// The live camera stage, styled after the reference design:
///
/// * top: a gray close (X) button, an orange "Ready for next scan." status
///   pill, and a blue "done" check (shown once pages exist);
/// * preview: live blue edge overlay;
/// * bottom: Flash / Filters / Shutter(auto) controls, a page thumbnail, and a
///   large white shutter.
///
/// Owns the [CameraController] and stays mounted across the crop stage so
/// returning to scan the next page does not re-initialize the camera.
class CameraView extends StatefulWidget {
  const CameraView({
    super.key,
    required this.controller,
    required this.style,
    required this.onDone,
    required this.onReview,
    required this.onCancel,
  });

  final PaperScannerController controller;
  final PaperScannerStyle style;
  final VoidCallback onDone;
  final VoidCallback onReview;
  final VoidCallback onCancel;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  static const double _topButtonBaseOffset = 8;
  static const double _topButtonExtraOffset = 30;
  static const double _readyStatusTopOffset = 110;

  CameraController? _camera;
  bool _initializing = true;
  bool _streaming = false;
  bool _capturing = false;
  DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);
  FlashMode _flashMode = FlashMode.off;
  int _stableHits = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerChanged);
    _setup();
  }

  Future<void> _setup() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        widget.controller.markPermissionDenied();
        if (mounted) setState(() => _initializing = false);
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      _initializing = false;
      widget.controller.markCameraReady();
      setState(() {});
      _ensureStreaming();
    } on CameraException catch (e) {
      scannerLog('camera init failed: ${e.code}');
      widget.controller.markPermissionDenied();
      if (mounted) setState(() => _initializing = false);
    } catch (e) {
      scannerLog('camera init error: $e');
      widget.controller.markPermissionDenied();
      if (mounted) setState(() => _initializing = false);
    }
  }

  void _onControllerChanged() {
    if (widget.controller.stage == ScanStage.camera) {
      _ensureStreaming();
      _maybeAutoCapture();
    } else {
      _stopStreamQuietly();
    }
  }

  void _ensureStreaming() {
    final camera = _camera;
    if (camera == null ||
        _streaming ||
        _capturing ||
        !camera.value.isInitialized ||
        !widget.controller.options.enableLiveDetection) {
      return;
    }
    _streaming = true;
    camera.startImageStream(_onFrame);
  }

  Future<void> _stopStreamQuietly() async {
    // Drop any in-progress auto-capture stability run so we never fire on a
    // stale quad after resuming.
    _stableHits = 0;
    _lastAutoQuad = null;
    if (!_streaming) return;
    _streaming = false;
    try {
      await _camera?.stopImageStream();
    } catch (_) {
      // stream may already be stopped
    }
  }

  void _onFrame(CameraImage image) {
    final now = DateTime.now();
    if (now.difference(_lastFrame) <
        widget.controller.options.detectionInterval) {
      return;
    }
    _lastFrame = now;
    final plane = image.planes.first;
    final format = image.format.group == ImageFormatGroup.bgra8888
        ? FrameFormat.bgra8888
        : FrameFormat.yuv420;
    widget.controller.detectLive(
      FrameData(
        bytes: plane.bytes,
        width: image.width,
        height: image.height,
        bytesPerRow: plane.bytesPerRow,
        rotation: _camera?.description.sensorOrientation ?? 0,
        format: format,
      ),
    );
  }

  /// Captures automatically once a document quad has been held reasonably
  /// still for a few consecutive detections (only when auto-shutter is on).
  ///
  /// Instead of waiting for a high raw confidence — which the area-based
  /// Android score rarely reaches — this fires when a decent quad stops moving,
  /// matching how the OS scanners "lock on". The motion gate keeps it from
  /// shooting a blurry frame while the user is still framing. The thresholds
  /// are tunable per project via [PaperScannerOptions].
  DetectedQuad? _lastAutoQuad;

  void _maybeAutoCapture() {
    if (!widget.controller.autoCapture || _capturing) return;
    final options = widget.controller.options;
    final quad = widget.controller.liveQuad;
    if (quad == null || quad.confidence < options.autoCaptureConfidence) {
      _stableHits = 0;
      _lastAutoQuad = quad;
      return;
    }
    final previous = _lastAutoQuad;
    if (previous != null &&
        _quadIsStill(
          previous.quad,
          quad.quad,
          options.autoCaptureMotionTolerance,
        )) {
      _stableHits++;
    } else {
      _stableHits = 1;
    }
    _lastAutoQuad = quad;
    if (_stableHits >= options.autoCaptureStableFrames) {
      _stableHits = 0;
      _lastAutoQuad = null;
      _capture();
    }
  }

  /// True when every corner of [b] is within [tolerance] of [a].
  bool _quadIsStill(Quad a, Quad b, double tolerance) {
    for (var i = 0; i < 4; i++) {
      final pa = a.corners[i];
      final pb = b.corners[i];
      if ((pa.x - pb.x).abs() > tolerance ||
          (pa.y - pb.y).abs() > tolerance) {
        return false;
      }
    }
    return true;
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null ||
        _capturing ||
        !camera.value.isInitialized ||
        !widget.controller.canAddMore) {
      return;
    }
    setState(() => _capturing = true);
    try {
      await _stopStreamQuietly();
      final file = await camera.takePicture();
      await widget.controller.onCaptured(file.path);
    } on CameraException catch (e) {
      scannerLog('capture failed: ${e.code}');
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
        // After a seamless (auto-keep) capture the controller is back on the
        // camera stage; resume realtime detection for the next page.
        if (widget.controller.stage == ScanStage.camera) _ensureStreaming();
      }
    }
  }

  Future<void> _cycleFlash() async {
    final camera = _camera;
    if (camera == null) return;
    final next = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await camera.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } on CameraException catch (e) {
      scannerLog('setFlashMode failed: ${e.code}');
    }
  }

  IconData get _currentFlashIcon => switch (_flashMode) {
    FlashMode.auto => Icons.flash_auto,
    FlashMode.always => Icons.flash_on,
    _ => Icons.flash_off,
  };

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          FilterPickerSheet(controller: widget.controller, style: widget.style),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopStreamQuietly();
    } else if (state == AppLifecycleState.resumed &&
        widget.controller.stage == ScanStage.camera) {
      _ensureStreaming();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerChanged);
    _stopStreamQuietly();
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final camera = _camera;
    if (_initializing || camera == null || !camera.value.isInitialized) {
      return Center(child: CircularProgressIndicator(color: style.accentColor));
    }
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final showChrome = widget.controller.stage == ScanStage.camera;
        return Stack(
          fit: StackFit.expand,
          children: [
            _FullScreenCameraPreview(
              camera: camera,
              controller: widget.controller,
              style: style,
            ),
            if (showChrome) _buildTopChrome(context),
            if (showChrome) _buildBottomChrome(context),
          ],
        );
      },
    );
  }

  // --- top chrome ---------------------------------------------------------

  Widget _buildTopChrome(BuildContext context) {
    final style = widget.style;
    if (style.cameraTopChromeBuilder != null) {
      return style.cameraTopChromeBuilder!(
        context,
        widget.controller,
        style,
        widget.onCancel,
        widget.onDone,
      );
    }
    final labels = style.labelsFor(context);
    final hasPages = widget.controller.pageCount > 0;
    final canFinish = widget.controller.canFinish;
    final buttonTop =
        MediaQuery.paddingOf(context).top +
        _topButtonBaseOffset +
        _topButtonExtraOffset;
    return Positioned.fill(
      child: Stack(
        children: [
          PositionedDirectional(
            top: buttonTop,
            start: 16,
            child: _circleIcon(
              Icons.close,
              widget.onCancel,
              key: const Key('paper_scanner_cancel_button'),
              background: style.surfaceColor.withValues(alpha: 0.6),
              foreground: style.foregroundColor,
            ),
          ),
          if (hasPages)
            Positioned(
              top: _readyStatusTopOffset,
              left: 0,
              right: 0,
              child: Center(
                child: _buildStatusPill(context, labels.readyForNextScan),
              ),
            ),
          PositionedDirectional(
            top: buttonTop,
            end: 16,
            child: Opacity(
              opacity: canFinish ? 1 : 0,
              child: IgnorePointer(
                ignoring: !canFinish,
                child: _circleIcon(
                  Icons.check,
                  widget.onDone,
                  key: const Key('paper_scanner_done_button'),
                  background: style.confirmColor,
                  foreground: style.onAccentColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- bottom chrome ------------------------------------------------------

  Widget _buildBottomChrome(BuildContext context) {
    final style = widget.style;
    if (style.cameraBottomChromeBuilder != null) {
      return style.cameraBottomChromeBuilder!(
        context,
        widget.controller,
        style,
        _capture,
        widget.onReview,
        _cycleFlash,
        _openFilters,
        widget.controller.toggleAutoCapture,
        _capturing,
        _currentFlashIcon,
      );
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: EdgeInsets.only(
          top: 14,
          bottom: MediaQuery.of(context).padding.bottom + 18,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              style.backgroundColor.withValues(alpha: 0.75),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControlsRow(),
            const SizedBox(height: 16),
            _buildShutterRow(context),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsRow() {
    final style = widget.style;
    final labels = style.labelsFor(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          context,
          key: const Key('paper_scanner_flash_control'),
          icon: _currentFlashIcon,
          label: labels.flash,
          onTap: _cycleFlash,
          active: _flashMode != FlashMode.off,
        ),
        const SizedBox(width: 28),
        _buildControlButton(
          context,
          key: const Key('paper_scanner_filters_control'),
          icon: Icons.photo_filter,
          label: labels.filters,
          onTap: _openFilters,
          active: widget.controller.sessionFilter != ScanFilter.original,
        ),
        const SizedBox(width: 28),
        _buildControlButton(
          context,
          key: const Key('paper_scanner_auto_shutter_control'),
          icon: widget.controller.autoCapture
              ? Icons.center_focus_strong
              : Icons.center_focus_weak,
          label: labels.autoShutter,
          active: widget.controller.autoCapture,
          onTap: widget.controller.toggleAutoCapture,
        ),
      ],
    );
  }

  Widget _buildShutterRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          SizedBox(width: 56, child: _buildThumbnail()),
          Expanded(child: Center(child: _buildShutter(context))),
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    final style = widget.style;
    final pages = widget.controller.pages;
    if (pages.isEmpty) return const SizedBox.shrink();
    if (style.pageThumbnailBuilder != null) {
      return style.pageThumbnailBuilder!(
        context,
        pages.last,
        widget.onReview,
        style,
      );
    }
    return GestureDetector(
      onTap: widget.onReview,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: style.thumbnailBorderColor ?? Colors.white,
            width: style.thumbnailBorderWidth ?? 2,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Image.file(
            File(pages.last.outputPath),
            width: 52,
            height: 64,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }

  Widget _buildShutter(BuildContext context) {
    final style = widget.style;
    if (style.captureButtonBuilder != null) {
      return style.captureButtonBuilder!(context, _capture, _capturing);
    }
    final labels = style.labelsFor(context);
    final enabled = widget.controller.canAddMore && !_capturing;
    return Semantics(
      button: true,
      enabled: enabled,
      label: labels.autoShutter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _capture : null,
        child: Container(
          key: const Key('paper_scanner_capture_button'),
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: style.shutterColor,
            border: Border.all(
              color:
                  style.shutterBorderColor ??
                  Colors.white.withValues(alpha: 0.6),
              width: style.shutterBorderWidth ?? 4,
            ),
          ),
          child: _capturing
              ? const Padding(
                  padding: EdgeInsets.all(22),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.black54,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildStatusPill(BuildContext context, String label) {
    final style = widget.style;
    final builder = style.statusPillBuilder;
    if (builder != null) {
      return KeyedSubtree(
        key: const Key('paper_scanner_ready_status'),
        child: builder(context, label, style),
      );
    }
    return _StatusPill(
      key: const Key('paper_scanner_ready_status'),
      label: label,
      style: style,
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool active,
  }) {
    final style = widget.style;
    return style.controlButtonBuilder?.call(
          context,
          icon,
          label,
          onTap,
          active,
          style,
        ) ??
        _ControlButton(
          key: key,
          icon: icon,
          label: label,
          style: style,
          onTap: onTap,
          active: active,
        );
  }

  Widget _circleIcon(
    IconData icon,
    VoidCallback onTap, {
    required Color background,
    required Color foreground,
    Key? key,
  }) {
    final builder = widget.style.iconButtonBuilder;
    if (builder != null) {
      return KeyedSubtree(
        key: key,
        child: builder(context, icon, onTap, background, foreground),
      );
    }
    return Material(
      key: key,
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: foreground, size: 24),
        ),
      ),
    );
  }
}

class _FullScreenCameraPreview extends StatelessWidget {
  const _FullScreenCameraPreview({
    required this.camera,
    required this.controller,
    required this.style,
  });

  final CameraController camera;
  final PaperScannerController controller;
  final PaperScannerStyle style;

  @override
  Widget build(BuildContext context) {
    final previewAspectRatio = 1 / camera.value.aspectRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Size(constraints.maxWidth, constraints.maxHeight);
        final fittedPreview = applyBoxFit(
          style.cameraPreviewFit,
          Size(previewAspectRatio, 1),
          bounds,
        ).destination;

        return ClipRect(
          key: const Key('paper_scanner_camera_preview'),
          child: Center(
            child: SizedBox(
              width: fittedPreview.width,
              height: fittedPreview.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(camera),
                  if (controller.options.enableLiveDetection)
                    CustomPaint(
                      painter: QuadOverlayPainter(
                        quad: controller.liveQuad?.quad,
                        strokeColor: style.overlayStrokeColor,
                        fillColor: style.effectiveOverlayFill,
                        strokeWidth: style.overlayStrokeWidth,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// An orange status pill ("Ready for next scan.").
class _StatusPill extends StatelessWidget {
  const _StatusPill({super.key, required this.label, required this.style});

  final String label;
  final PaperScannerStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        color: style.accentColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            style.statusPillTextStyle ??
            TextStyle(
              color: style.onAccentColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

/// A camera control: gray circular icon button with a label underneath.
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.style,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final PaperScannerStyle style;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? style.accentColor
                      : style.surfaceColor.withValues(alpha: 0.7),
                ),
                child: Icon(
                  icon,
                  color: active ? style.onAccentColor : style.foregroundColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    style.controlLabelTextStyle ??
                    TextStyle(color: style.foregroundColor, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
