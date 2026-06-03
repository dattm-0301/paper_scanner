import 'dart:io';

import 'package:flutter/material.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

import '../paper_scanner_controller.dart';
import '../paper_scanner_style.dart';
import 'quad_overlay_painter.dart';

/// The review/crop stage: the captured still with draggable white ring corner
/// handles seeded from the detected quad, plus "Retake" (top-left) and "Keep"
/// (top-right) pills.
///
/// The image is laid out in an [AspectRatio] that exactly bounds it, so the
/// normalized corners map 1:1 onto the layout box.
class CropView extends StatefulWidget {
  const CropView({
    super.key,
    required this.controller,
    required this.style,
    required this.onKeep,
    required this.onRetake,
  });

  final PaperScannerController controller;
  final PaperScannerStyle style;
  final VoidCallback onKeep;
  final VoidCallback onRetake;

  @override
  State<CropView> createState() => _CropViewState();
}

class _CropViewState extends State<CropView> {
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
  }

  void _resolveImageSize() {
    final path = widget.controller.draft?.originalPath;
    if (path == null) return;
    final stream = FileImage(File(path)).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      if (mounted) {
        setState(() {
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      }
      stream.removeListener(listener);
    });
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final labels = style.labelsFor(context);
    final draft = widget.controller.draft;
    final size = _imageSize;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (draft == null || size == null)
          Center(child: CircularProgressIndicator(color: style.accentColor))
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 96),
            child: Center(
              child: AspectRatio(
                aspectRatio: size.width / size.height,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final box = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return AnimatedBuilder(
                      animation: widget.controller,
                      builder: (context, _) {
                        final quad =
                            widget.controller.draft?.quad ?? Quad.full();
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Image.file(
                                File(draft.originalPath),
                                fit: BoxFit.fill,
                                gaplessPlayback: true,
                              ),
                            ),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: QuadOverlayPainter(
                                  quad: quad,
                                  strokeColor: style.cornerHandleColor,
                                  fillColor: style.effectiveOverlayFill,
                                  strokeWidth: 2,
                                  cornerDotRadius: 0,
                                ),
                              ),
                            ),
                            for (var i = 0; i < 4; i++)
                              _buildHandle(i, quad.corners[i], box),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),

        // Top pills: Retake (left) / Keep (right).
        if (style.cropActionsBuilder != null)
          style.cropActionsBuilder!(
            context,
            widget.controller,
            style,
            widget.onRetake,
            widget.onKeep,
          )
        else
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCropAction(
                      label: labels.retake,
                      primary: false,
                      busy: false,
                      onTap: widget.controller.busy ? null : widget.onRetake,
                    ),
                    _buildCropAction(
                      label: labels.keep,
                      primary: true,
                      busy: widget.controller.busy,
                      onTap: widget.controller.busy ? null : widget.onKeep,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCropAction({
    required String label,
    required bool primary,
    required bool busy,
    required VoidCallback? onTap,
  }) {
    final style = widget.style;
    final builder = style.cropActionButtonBuilder;
    if (builder != null) {
      return builder(context, label, onTap, primary, busy, style);
    }
    return _Pill(
      key: Key(
        primary ? 'paper_scanner_keep_button' : 'paper_scanner_retake_button',
      ),
      label: label,
      background: primary ? style.accentColor : style.onAccentColor,
      foreground: primary ? style.onAccentColor : style.accentColor,
      borderColor: primary ? const Color(0xFF979797) : null,
      busy: busy,
      textStyle: style.cropActionTextStyle,
      onTap: onTap,
    );
  }

  Widget _buildHandle(int index, ScanPoint corner, Size box) {
    final style = widget.style;
    final r = style.cornerHandleRadius;
    const touch = 48.0;
    final px = corner.x * box.width;
    final py = corner.y * box.height;
    return Positioned(
      left: px - touch / 2,
      top: py - touch / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          final q = widget.controller.draft?.quad ?? Quad.full();
          final current = q.corners[index];
          final nx = (current.x + details.delta.dx / box.width).clamp(0.0, 1.0);
          final ny = (current.y + details.delta.dy / box.height).clamp(
            0.0,
            1.0,
          );
          widget.controller.updateDraftQuad(
            q.copyWithCorner(index, ScanPoint(nx, ny)),
          );
        },
        child: SizedBox(
          width: touch,
          height: touch,
          child: Center(
            child:
                style.cornerHandleBuilder?.call(context) ??
                Container(
                  width: r * 2,
                  height: r * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                    border: Border.all(
                      color: style.cornerHandleColor,
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 3),
                    ],
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

/// A rounded pill button matching the reference design.
class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.borderColor,
    this.busy = false,
    this.textStyle,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final bool busy;
  final TextStyle? textStyle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Container(
          constraints: const BoxConstraints(minWidth: 73, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(35),
            border: borderColor != null
                ? Border.all(color: borderColor!)
                : null,
          ),
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              : Text(
                  label,
                  style:
                      textStyle ??
                      TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                ),
        ),
      ),
    );
  }
}
