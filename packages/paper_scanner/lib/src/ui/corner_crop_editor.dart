import 'dart:io';

import 'package:flutter/material.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

import '../paper_scanner_style.dart';
import 'quad_overlay_painter.dart';

/// A reusable, draggable four-corner crop editor.
///
/// Lays the image inside an [AspectRatio] that exactly bounds it, so the
/// normalized [quad] corners map 1:1 onto the layout box. Dragging a corner
/// calls [onChanged] with the updated quad (clamped to the unit square). While a
/// corner is dragged a magnifier loupe shows the pixels under the finger — the
/// same affordance the OS scanners (VisionKit / ML Kit) provide.
///
/// Shared by the post-capture confirm crop ([CropView]) and the detail-view
/// re-crop screen so both behave identically.
class CornerCropEditor extends StatefulWidget {
  const CornerCropEditor({
    super.key,
    required this.imagePath,
    required this.quad,
    required this.onChanged,
    required this.style,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    this.magnify = true,
  });

  /// The image whose corners are being adjusted (the original capture).
  final String imagePath;

  /// The current normalized crop quad.
  final Quad quad;

  /// Called with the new quad whenever a corner is dragged.
  final ValueChanged<Quad> onChanged;

  final PaperScannerStyle style;

  /// Padding around the bounded image inside the available space.
  final EdgeInsets padding;

  /// Whether to show a magnifier loupe while dragging a corner.
  final bool magnify;

  @override
  State<CornerCropEditor> createState() => _CornerCropEditorState();
}

class _CornerCropEditorState extends State<CornerCropEditor> {
  static const double _touch = 48;
  static const double _loupeDiameter = 104;
  static const double _loupeGap = 28;

  Size? _imageSize;
  int _activeCorner = -1;
  Offset _activePoint = Offset.zero; // in layout-box coordinates

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
  }

  @override
  void didUpdateWidget(CornerCropEditor old) {
    super.didUpdateWidget(old);
    if (old.imagePath != widget.imagePath) {
      _imageSize = null;
      _resolveImageSize();
    }
  }

  void _resolveImageSize() {
    final stream = FileImage(
      File(widget.imagePath),
    ).resolve(const ImageConfiguration());
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
    final size = _imageSize;
    if (size == null) {
      return Center(child: CircularProgressIndicator(color: style.accentColor));
    }
    return Padding(
      padding: widget.padding,
      child: Center(
        child: AspectRatio(
          aspectRatio: size.width / size.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final box = Size(constraints.maxWidth, constraints.maxHeight);
              final quad = widget.quad;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Image.file(
                      File(widget.imagePath),
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
                  if (widget.magnify && _activeCorner >= 0) _buildLoupe(box),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(int index, ScanPoint corner, Size box) {
    final style = widget.style;
    final r = style.cornerHandleRadius;
    final px = corner.x * box.width;
    final py = corner.y * box.height;
    return Positioned(
      left: px - _touch / 2,
      top: py - _touch / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() {
          _activeCorner = index;
          _activePoint = Offset(px, py);
        }),
        onPanUpdate: (details) {
          final q = widget.quad;
          final current = q.corners[index];
          final nx = (current.x + details.delta.dx / box.width).clamp(0.0, 1.0);
          final ny = (current.y + details.delta.dy / box.height).clamp(
            0.0,
            1.0,
          );
          setState(
            () => _activePoint = Offset(nx * box.width, ny * box.height),
          );
          widget.onChanged(q.copyWithCorner(index, ScanPoint(nx, ny)));
        },
        onPanEnd: (_) => setState(() => _activeCorner = -1),
        onPanCancel: () => setState(() => _activeCorner = -1),
        child: SizedBox(
          width: _touch,
          height: _touch,
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

  /// A circular magnifier shown above (or below, near the top edge) the active
  /// corner, focused on the pixels under the finger.
  Widget _buildLoupe(Size box) {
    final showBelow = _activePoint.dy < _loupeDiameter + _loupeGap;
    final centerY = showBelow
        ? _activePoint.dy + _loupeGap + _loupeDiameter / 2
        : _activePoint.dy - _loupeGap - _loupeDiameter / 2;
    final left = (_activePoint.dx - _loupeDiameter / 2).clamp(
      0.0,
      (box.width - _loupeDiameter).clamp(0.0, double.infinity),
    );
    final top = centerY - _loupeDiameter / 2;
    // The magnifier's own center maps to (left + d/2, top + d/2); shift the
    // magnified source so it samples the corner under the finger.
    final focal = Offset(
      _activePoint.dx - (left + _loupeDiameter / 2),
      _activePoint.dy - (top + _loupeDiameter / 2),
    );
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: RawMagnifier(
          decoration: MagnifierDecoration(
            shape: const CircleBorder(
              side: BorderSide(color: Colors.white, width: 3),
            ),
          ),
          size: const Size(_loupeDiameter, _loupeDiameter),
          focalPointOffset: focal,
          magnificationScale: 1.8,
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }
}
