import 'package:flutter/material.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

import '../paper_scanner_controller.dart';
import '../paper_scanner_style.dart';
import 'corner_crop_editor.dart';

/// Full-screen re-crop tool opened from the detail/edit view.
///
/// Edits the corner [Quad] of a committed page on its **original** capture
/// (rotation is a separate, later step), then commits the change through
/// [PaperScannerController.recropPage]. Cancelling leaves the page untouched.
class RecropScreen extends StatefulWidget {
  const RecropScreen({
    super.key,
    required this.controller,
    required this.pageIndex,
    required this.style,
  });

  final PaperScannerController controller;
  final int pageIndex;
  final PaperScannerStyle style;

  @override
  State<RecropScreen> createState() => _RecropScreenState();
}

class _RecropScreenState extends State<RecropScreen> {
  late Quad _quad;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final pages = widget.controller.pages;
    final page = (widget.pageIndex >= 0 && widget.pageIndex < pages.length)
        ? pages[widget.pageIndex]
        : null;
    _quad = page?.quad ?? Quad.full();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await widget.controller.recropPage(widget.pageIndex, _quad.clamped);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final labels = style.labelsFor(context);
    final pages = widget.controller.pages;
    if (widget.pageIndex < 0 || widget.pageIndex >= pages.length) {
      // Page vanished (e.g. deleted) — bail out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return Scaffold(backgroundColor: style.backgroundColor);
    }
    final page = pages[widget.pageIndex];

    return Scaffold(
      key: const Key('paper_scanner_recrop_screen'),
      backgroundColor: style.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              style: style,
              title: labels.crop,
              cancelLabel: labels.cancel,
              saveLabel: labels.done,
              saving: _saving,
              onCancel: () => Navigator.of(context).pop(),
              onSave: _save,
            ),
            Expanded(
              child: CornerCropEditor(
                imagePath: page.originalPath,
                quad: _quad,
                onChanged: (q) => setState(() => _quad = q),
                style: style,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.style,
    required this.title,
    required this.cancelLabel,
    required this.saveLabel,
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final PaperScannerStyle style;
  final String title;
  final String cancelLabel;
  final String saveLabel;
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: style.foregroundColor,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('paper_scanner_recrop_cancel'),
              onPressed: saving ? null : onCancel,
              child: Text(
                cancelLabel,
                style: TextStyle(color: style.foregroundColor, fontSize: 16),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('paper_scanner_recrop_done'),
              onPressed: saving ? null : onSave,
              child: saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: style.accentColor,
                      ),
                    )
                  : Text(
                      saveLabel,
                      style: TextStyle(
                        color: style.accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
