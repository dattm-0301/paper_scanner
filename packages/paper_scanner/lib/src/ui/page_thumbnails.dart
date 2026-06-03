import 'dart:io';

import 'package:flutter/material.dart';

import '../paper_scan_result.dart';
import '../paper_scanner_controller.dart';
import '../paper_scanner_style.dart';

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

/// Bottom sheet for reviewing committed pages — reorder by drag, delete by tap.
class PageReviewSheet extends StatelessWidget {
  const PageReviewSheet({
    super.key,
    required this.controller,
    required this.style,
  });

  final PaperScannerController controller;
  final PaperScannerStyle style;

  @override
  Widget build(BuildContext context) {
    final labels = style.labels;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pages = controller.pages;
        return SafeArea(
          child: Container(
            color: style.surfaceColor,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        labels.review,
                        style: TextStyle(
                          color: style.foregroundColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: style.foregroundColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: pages.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final legacyNewIndex =
                          newIndex > oldIndex ? newIndex + 1 : newIndex;
                      controller.reorderPages(oldIndex, legacyNewIndex);
                    },
                    itemBuilder: (context, index) {
                      final page = pages[index];
                      return ListTile(
                        key: ValueKey(page.originalPath),
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(page.outputPath),
                            width: 44,
                            height: 56,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                        title: Text(
                          '${labels.pageCounter} ${index + 1}',
                          style: TextStyle(color: style.foregroundColor),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.redAccent),
                          onPressed: () => controller.deletePage(index),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
