import 'package:flutter/material.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

import '../paper_scanner_controller.dart';
import '../paper_scanner_style.dart';

/// Bottom sheet opened from the camera "Filters" control.
///
/// Lets the user pick the [ScanFilter] applied to each kept page
/// ([PaperScannerController.sessionFilter]). Kept lightweight so it can sit
/// over the live preview.
class FilterPickerSheet extends StatelessWidget {
  const FilterPickerSheet({
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
        final selected = controller.sessionFilter;
        return SafeArea(
          child: Container(
            color: style.surfaceColor,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labels.filters,
                  style: TextStyle(
                    color: style.foregroundColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final filter in ScanFilter.values)
                      ChoiceChip(
                        label: Text(labels.filterName(filter)),
                        selected: selected == filter,
                        showCheckmark: false,
                        backgroundColor: style.backgroundColor,
                        selectedColor: style.effectiveChipSelected,
                        labelStyle: TextStyle(
                          color: selected == filter
                              ? style.onAccentColor
                              : style.foregroundColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: style.foregroundColor.withValues(alpha: 0.2),
                          ),
                        ),
                        onSelected: (_) => controller.setSessionFilter(filter),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
