import 'dart:io';

import 'package:flutter/material.dart';

import '../paper_scan_result.dart';
import '../paper_scanner_controller.dart';
import '../paper_scanner_style.dart';
import 'page_editor_view.dart';

/// Horizontal strip of captured-page thumbnails shown on the camera stage.
class PageThumbnailStrip extends StatelessWidget {
  const PageThumbnailStrip({
    super.key,
    required this.pages,
    required this.style,
    this.onTap,
    this.height = 64,
  });

  final List<ScannedPage> pages;
  final PaperScannerStyle style;
  final void Function(int index)? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: pages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => onTap?.call(index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.file(
                File(pages[index].outputPath),
                width: height * 0.74,
                height: height,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bottom sheet for reviewing committed pages — reorder by drag, delete by tap,
/// tap a row to open the full-screen detail/edit view.
class PageReviewSheet extends StatelessWidget {
  const PageReviewSheet({
    super.key,
    required this.controller,
    required this.style,
    this.onPreview,
  });

  final PaperScannerController controller;
  final PaperScannerStyle style;

  /// Called when a page row is tapped. Defaults to pushing [PageEditorScreen]
  /// (the full detail/edit view) for that page.
  final void Function(int index)? onPreview;

  @override
  Widget build(BuildContext context) {
    final labels = style.labelsFor(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pages = controller.pages;

        final preview =
            onPreview ??
            (int index) {
              if (index < 0 || index >= pages.length) return;
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => PageEditorScreen(
                    controller: controller,
                    initialIndex: index,
                    style: style,
                  ),
                ),
              );
            };

        void onDelete(int index) => controller.deletePage(index);

        final sheetBuilder = style.pageReviewSheetBuilder;
        if (sheetBuilder != null) {
          return sheetBuilder(
            context,
            controller,
            style,
            labels,
            () => Navigator.of(context).pop(),
            preview,
            onDelete,
          );
        }

        return _DefaultPageReviewSheet(
          controller: controller,
          pages: pages,
          style: style,
          labels: labels,
          onClose: () => Navigator.of(context).pop(),
          onPreview: preview,
          onDelete: onDelete,
        );
      },
    );
  }
}

class _DefaultPageReviewSheet extends StatelessWidget {
  const _DefaultPageReviewSheet({
    required this.controller,
    required this.pages,
    required this.style,
    required this.labels,
    required this.onClose,
    required this.onPreview,
    required this.onDelete,
  });

  final PaperScannerController controller;
  final List<ScannedPage> pages;
  final PaperScannerStyle style;
  final PaperScannerLabels labels;
  final VoidCallback onClose;
  final void Function(int index) onPreview;
  final void Function(int index) onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: style.surfaceColor,
        padding: style.reviewSheetPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: style.reviewHeaderPadding,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  key: const Key('paper_scanner_review_close_button'),
                  tooltip: labels.cancel,
                  icon: Icon(
                    style.reviewCloseIcon,
                    color: style.foregroundColor,
                  ),
                  onPressed: onClose,
                ),
              ),
            ),
            Flexible(
              child: _PageReviewList(
                controller: controller,
                pages: pages,
                style: style,
                labels: labels,
                onPreview: onPreview,
                onDelete: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageReviewList extends StatelessWidget {
  const _PageReviewList({
    required this.controller,
    required this.pages,
    required this.style,
    required this.labels,
    required this.onPreview,
    required this.onDelete,
  });

  final PaperScannerController controller;
  final List<ScannedPage> pages;
  final PaperScannerStyle style;
  final PaperScannerLabels labels;
  final void Function(int index) onPreview;
  final void Function(int index) onDelete;

  @override
  Widget build(BuildContext context) {
    void onReorder(int oldIndex, int newIndex) {
      final legacyNewIndex = newIndex > oldIndex ? newIndex + 1 : newIndex;
      controller.reorderPages(oldIndex, legacyNewIndex);
    }

    final listBuilder = style.pageReviewListBuilder;
    if (listBuilder != null) {
      return listBuilder(
        context,
        controller,
        pages,
        style,
        labels,
        onReorder,
        onPreview,
        onDelete,
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      padding: style.reviewListPadding,
      itemCount: pages.length,
      onReorderItem: onReorder,
      itemBuilder: (context, index) {
        final page = pages[index];
        final label = '${labels.pageCounter} ${index + 1}';
        final dragHandle = ReorderableDragStartListener(
          index: index,
          child: Icon(
            style.reviewDragHandleIcon,
            color: style.foregroundColor.withValues(alpha: 0.55),
          ),
        );
        final customTile = style.pageReviewTileBuilder?.call(
          context,
          page,
          index,
          label,
          style,
          labels,
          () => onPreview(index),
          () => onDelete(index),
          dragHandle,
        );
        return Padding(
          key: ValueKey(page.originalPath),
          padding: EdgeInsets.only(
            bottom: index == pages.length - 1 ? 0 : style.reviewItemSpacing,
          ),
          child:
              customTile ??
              _DefaultPageReviewTile(
                key: Key('paper_scanner_review_item_$index'),
                page: page,
                label: label,
                style: style,
                labels: labels,
                dragHandle: dragHandle,
                onPreview: () => onPreview(index),
                onDelete: () => onDelete(index),
              ),
        );
      },
    );
  }
}

class _DefaultPageReviewTile extends StatelessWidget {
  const _DefaultPageReviewTile({
    super.key,
    required this.page,
    required this.label,
    required this.style,
    required this.labels,
    required this.dragHandle,
    required this.onPreview,
    required this.onDelete,
  });

  final ScannedPage page;
  final String label;
  final PaperScannerStyle style;
  final PaperScannerLabels labels;
  final Widget dragHandle;
  final VoidCallback onPreview;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: style.backgroundColor.withValues(alpha: 0.34),
      borderRadius: BorderRadius.circular(style.reviewItemBorderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPreview,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: style.reviewTileMinHeight),
          child: Padding(
            padding: style.reviewItemPadding,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(page.outputPath),
                    width: style.reviewThumbnailSize.width,
                    height: style.reviewThumbnailSize.height,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        style.reviewPageTextStyle ??
                        TextStyle(
                          color: style.foregroundColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(child: dragHandle),
                ),
                IconButton(
                  key: const Key('paper_scanner_review_delete_button'),
                  tooltip: labels.delete,
                  icon: Icon(style.reviewDeleteIcon),
                  color: style.reviewDeleteColor,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
