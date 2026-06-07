import 'dart:io';

import 'package:flutter/material.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

import '../paper_scan_result.dart';
import '../paper_scanner_controller.dart';
import '../paper_scanner_style.dart';
import 'page_thumbnails.dart';
import 'recrop_screen.dart';

/// Full-screen page detail/edit view — the "full view" opened by tapping a page
/// preview.
///
/// Swipe between committed pages; per page, the bottom toolbar offers the same
/// tools the OS scanners expose: **Crop** (re-adjust corners), **Rotate**,
/// **Filter** and **Delete**. The layout adapts to [PaperScannerStyle.skin]:
/// VisionKit-style on iOS, ML Kit-style on Android.
class PageEditorScreen extends StatefulWidget {
  const PageEditorScreen({
    super.key,
    required this.controller,
    required this.initialIndex,
    required this.style,
  });

  final PaperScannerController controller;
  final int initialIndex;
  final PaperScannerStyle style;

  @override
  State<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends State<PageEditorScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _filtersOpen = false;

  PaperScannerStyle get style => widget.style;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  Future<void> _openCrop(int index) async {
    setState(() => _filtersOpen = false);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => RecropScreen(
          controller: widget.controller,
          pageIndex: index,
          style: style,
        ),
      ),
    );
  }

  void _rotate(int index) {
    if (widget.controller.busy) return;
    widget.controller.rotatePage(index);
  }

  void _setFilter(int index, ScanFilter filter) {
    if (widget.controller.busy) return;
    widget.controller.setPageFilter(index, filter);
  }

  /// Opens the multi-page overview (reorder by drag, delete) and jumps the
  /// editor to a page when one is tapped.
  void _showPages() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PageReviewSheet(
        controller: widget.controller,
        style: style,
        onPreview: (i) {
          Navigator.of(context).pop();
          setState(() => _currentIndex = i);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pageController.hasClients) {
              _pageController.jumpToPage(i);
            }
          });
        },
      ),
    );
  }

  void _deleteCurrent(List<ScannedPage> pages) {
    if (_currentIndex < 0 || _currentIndex >= pages.length) return;
    final shouldClose = pages.length == 1;
    final nextIndex = _currentIndex >= pages.length - 1
        ? pages.length - 2
        : _currentIndex;

    widget.controller.deletePage(_currentIndex);
    if (shouldClose) {
      _close();
      return;
    }
    setState(() => _currentIndex = nextIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }

  int _clampedIndex(int pageCount) {
    final safe = _currentIndex.clamp(0, pageCount - 1);
    if (safe != _currentIndex) {
      _currentIndex = safe;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(_currentIndex);
        }
      });
    }
    return safe;
  }

  @override
  Widget build(BuildContext context) {
    final labels = style.labelsFor(context);
    final cupertino = style.isCupertino(context);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final pages = widget.controller.pages;
        if (pages.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
          return Scaffold(
            key: const Key('paper_scanner_page_preview'),
            backgroundColor: style.reviewPreviewBackgroundColor ?? Colors.black,
          );
        }

        final index = _clampedIndex(pages.length);
        final page = pages[index];
        final label = '${labels.pageCounter} ${index + 1}';

        // Full custom replacement, if provided.
        final previewBuilder = style.pagePreviewBuilder;
        if (previewBuilder != null) {
          return previewBuilder(
            context,
            page,
            index,
            label,
            style,
            labels,
            _close,
            () => _deleteCurrent(pages),
          );
        }

        return Scaffold(
          key: const Key('paper_scanner_page_preview'),
          backgroundColor: style.reviewPreviewBackgroundColor ?? Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                key: const Key('paper_scanner_page_preview_view'),
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, i) => _EditorImagePage(
                  key: Key('paper_scanner_page_preview_item_$i'),
                  page: pages[i],
                ),
              ),
              _TopChrome(
                cupertino: cupertino,
                style: style,
                label: label,
                pageCount: pages.length,
                index: index,
                doneLabel: labels.done,
                onClose: _close,
                onPages: pages.length > 1 ? _showPages : null,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomTools(
                  cupertino: cupertino,
                  style: style,
                  labels: labels,
                  filtersOpen: _filtersOpen,
                  currentFilter: page.filter,
                  busy: widget.controller.busy,
                  onCrop: () => _openCrop(index),
                  onRotate: () => _rotate(index),
                  onToggleFilters: () =>
                      setState(() => _filtersOpen = !_filtersOpen),
                  onPickFilter: (f) => _setFilter(index, f),
                  onDelete: () => _deleteCurrent(pages),
                ),
              ),
              if (widget.controller.busy)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(color: Color(0x33000000)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A single zoomable page image; reflects baked rotation via [outputPath].
class _EditorImagePage extends StatelessWidget {
  const _EditorImagePage({super.key, required this.page});

  final ScannedPage page;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          panEnabled: false,
          minScale: 1,
          maxScale: 4,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 96, 8, 150),
              child: Image.file(
                File(page.outputPath),
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.cupertino,
    required this.style,
    required this.label,
    required this.pageCount,
    required this.index,
    required this.doneLabel,
    required this.onClose,
    this.onPages,
  });

  final bool cupertino;
  final PaperScannerStyle style;
  final String label;
  final int pageCount;
  final int index;
  final String doneLabel;
  final VoidCallback onClose;
  final VoidCallback? onPages;

  @override
  Widget build(BuildContext context) {
    final counter = pageCount > 1 ? '${index + 1} / $pageCount' : label;
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 6,
          bottom: 10,
          left: 8,
          right: 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.55),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              key: const Key('paper_scanner_editor_close'),
              icon: Icon(
                cupertino ? Icons.arrow_back_ios_new : Icons.close,
                color: Colors.white,
              ),
              onPressed: onClose,
            ),
            Expanded(
              child: Text(
                counter,
                key: const Key('paper_scanner_editor_counter'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onPages != null)
              IconButton(
                key: const Key('paper_scanner_editor_pages'),
                icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
                onPressed: onPages,
              ),
            if (cupertino)
              TextButton(
                key: const Key('paper_scanner_editor_done'),
                onPressed: onClose,
                child: Text(
                  doneLabel,
                  style: TextStyle(
                    color: style.confirmColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              IconButton(
                key: const Key('paper_scanner_editor_done'),
                icon: Icon(Icons.check, color: style.confirmColor),
                onPressed: onClose,
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomTools extends StatelessWidget {
  const _BottomTools({
    required this.cupertino,
    required this.style,
    required this.labels,
    required this.filtersOpen,
    required this.currentFilter,
    required this.busy,
    required this.onCrop,
    required this.onRotate,
    required this.onToggleFilters,
    required this.onPickFilter,
    required this.onDelete,
  });

  final bool cupertino;
  final PaperScannerStyle style;
  final PaperScannerLabels labels;
  final bool filtersOpen;
  final ScanFilter currentFilter;
  final bool busy;
  final VoidCallback onCrop;
  final VoidCallback onRotate;
  final VoidCallback onToggleFilters;
  final ValueChanged<ScanFilter> onPickFilter;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tools = <Widget>[
      _ToolButton(
        key: const Key('paper_scanner_editor_crop'),
        icon: Icons.crop,
        label: labels.crop,
        onTap: busy ? null : onCrop,
        style: style,
      ),
      _ToolButton(
        key: const Key('paper_scanner_editor_rotate'),
        icon: Icons.rotate_right,
        label: labels.rotate,
        onTap: busy ? null : onRotate,
        style: style,
      ),
      _ToolButton(
        key: const Key('paper_scanner_editor_filter'),
        icon: Icons.photo_filter,
        label: labels.filters,
        active: filtersOpen || currentFilter != ScanFilter.original,
        onTap: busy ? null : onToggleFilters,
        style: style,
      ),
      _ToolButton(
        key: const Key('paper_scanner_preview_delete_button'),
        icon: Icons.delete_outline,
        label: labels.delete,
        tint: style.reviewDeleteColor,
        onTap: busy ? null : onDelete,
        style: style,
      ),
    ];

    return Container(
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: cupertino
            ? Colors.black.withValues(alpha: 0.4)
            : style.surfaceColor,
        gradient: cupertino
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
              )
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (filtersOpen)
            _FilterStrip(
              style: style,
              labels: labels,
              current: currentFilter,
              onPick: onPickFilter,
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: tools,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.style,
    this.active = false,
    this.tint,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final PaperScannerStyle style;
  final bool active;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color =
        tint ?? (active ? style.accentColor : Colors.white);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: SizedBox(
            width: 76,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 5),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal row of per-page filter choices, shown above the tools when the
/// Filter tool is open.
class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.style,
    required this.labels,
    required this.current,
    required this.onPick,
  });

  final PaperScannerStyle style;
  final PaperScannerLabels labels;
  final ScanFilter current;
  final ValueChanged<ScanFilter> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('paper_scanner_editor_filter_bar'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final filter in ScanFilter.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(labels.filterName(filter)),
                  selected: current == filter,
                  showCheckmark: false,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  selectedColor: style.effectiveChipSelected,
                  labelStyle: TextStyle(
                    color: current == filter
                        ? style.onAccentColor
                        : Colors.white,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  onSelected: (_) => onPick(filter),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
