import 'package:flutter/material.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

import '../paper_scanner_controller.dart';
import '../paper_scanner_style.dart';
import 'corner_crop_editor.dart';

/// The post-capture review/crop stage used by the legacy
/// [PaperScannerOptions.confirmAfterCapture] flow: the captured still with
/// draggable corner handles seeded from the detected quad, plus "Retake"
/// (top-left) and "Keep" (top-right) pills.
class CropView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final labels = style.labelsFor(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final draft = controller.draft;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (draft == null)
              Center(
                child: CircularProgressIndicator(color: style.accentColor),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 96,
                ),
                child: CornerCropEditor(
                  imagePath: draft.originalPath,
                  quad: draft.quad ?? Quad.full(),
                  onChanged: controller.updateDraftQuad,
                  style: style,
                  padding: EdgeInsets.zero,
                ),
              ),

            // Top pills: Retake (left) / Keep (right).
            if (style.cropActionsBuilder != null)
              style.cropActionsBuilder!(
                context,
                controller,
                style,
                onRetake,
                onKeep,
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
                          context,
                          label: labels.retake,
                          primary: false,
                          busy: false,
                          onTap: controller.busy ? null : onRetake,
                        ),
                        _buildCropAction(
                          context,
                          label: labels.keep,
                          primary: true,
                          busy: controller.busy,
                          onTap: controller.busy ? null : onKeep,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCropAction(
    BuildContext context, {
    required String label,
    required bool primary,
    required bool busy,
    required VoidCallback? onTap,
  }) {
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
