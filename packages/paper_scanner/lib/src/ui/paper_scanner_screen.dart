import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../paper_scan_result.dart';
import '../paper_scanner_controller.dart';
import '../paper_scanner_options.dart';
import '../paper_scanner_style.dart';
import 'camera_view.dart';
import 'crop_view.dart';
import 'page_thumbnails.dart';

/// The full-screen scanner UI.
///
/// Owns a [PaperScannerController] for the session, switches between the
/// camera and crop stages, and pops with a [PaperScanResult] (or `null` if
/// cancelled). Typically launched via `PaperScanner.open`.
class PaperScannerScreen extends StatefulWidget {
  const PaperScannerScreen({
    super.key,
    this.options = const PaperScannerOptions(),
    this.style = const PaperScannerStyle(),
  });

  final PaperScannerOptions options;
  final PaperScannerStyle style;

  @override
  State<PaperScannerScreen> createState() => _PaperScannerScreenState();
}

class _PaperScannerScreenState extends State<PaperScannerScreen> {
  late final PaperScannerController _controller = PaperScannerController(
    options: widget.options,
  );

  // Bumped to force a fresh CameraView (and camera re-init) on permission retry.
  int _cameraAttempt = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final result = await _controller.finish();
    if (mounted) Navigator.of(context).pop(result);
  }

  void _cancel() => Navigator.of(context).pop();

  void _retryCamera() {
    _controller.retryCamera();
    setState(() => _cameraAttempt++);
  }

  void _openReview() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          PageReviewSheet(controller: _controller, style: widget.style),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final labels = style.labelsFor(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: style.systemOverlayStyle ?? SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          switch (_controller.stage) {
            case ScanStage.crop:
              _controller.retakeDraft();
            case ScanStage.processing:
            case ScanStage.finished:
              break;
            case ScanStage.initializing:
            case ScanStage.permissionDenied:
            case ScanStage.camera:
              _cancel();
          }
        },
        child: Scaffold(
          backgroundColor: style.backgroundColor,
          body: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Camera stays mounted across the crop stage so we never pay
                  // for a full re-initialization when scanning more pages.
                  CameraView(
                    key: ValueKey('camera_$_cameraAttempt'),
                    controller: _controller,
                    style: style,
                    onDone: _finish,
                    onReview: _openReview,
                    onCancel: _cancel,
                  ),

                  if (_controller.stage == ScanStage.crop)
                    Positioned.fill(
                      child: ColoredBox(
                        color: style.backgroundColor,
                        child: CropView(
                          controller: _controller,
                          style: style,
                          onKeep: _controller.keepDraft,
                          onRetake: _controller.retakeDraft,
                        ),
                      ),
                    ),

                  if (_controller.stage == ScanStage.permissionDenied)
                    Positioned.fill(
                      child: _PermissionView(
                        style: style,
                        onRetry: _retryCamera,
                        onCancel: _cancel,
                      ),
                    ),

                  if (_controller.stage == ScanStage.processing)
                    Positioned.fill(
                      child: ColoredBox(
                        color: style.backgroundColor.withValues(alpha: 0.8),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: style.accentColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                labels.processing,
                                style: TextStyle(color: style.foregroundColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Shown when camera permission is unavailable.
class _PermissionView extends StatelessWidget {
  const _PermissionView({
    required this.style,
    required this.onRetry,
    required this.onCancel,
  });

  final PaperScannerStyle style;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final labels = style.labelsFor(context);
    return ColoredBox(
      color: style.backgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: Icon(Icons.close, color: style.foregroundColor),
                  onPressed: onCancel,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.no_photography_outlined,
                color: style.foregroundColor,
                size: 56,
              ),
              const SizedBox(height: 20),
              Text(
                labels.cameraPermissionTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: style.foregroundColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                labels.cameraPermissionMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: style.foregroundColor.withValues(alpha: 0.75),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: style.accentColor,
                  foregroundColor: style.onAccentColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                ),
                child: Text(labels.retryCamera),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
