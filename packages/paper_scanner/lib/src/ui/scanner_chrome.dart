import 'package:flutter/material.dart';

import '../paper_scanner_style.dart';

/// A simple top bar with a back button and a centered [title].
class ScannerTopBar extends StatelessWidget {
  const ScannerTopBar({
    super.key,
    required this.title,
    required this.style,
    required this.onBack,
  });

  final String title;
  final PaperScannerStyle style;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: style.foregroundColor),
                onPressed: onBack,
              ),
            ),
            Center(
              child: Text(
                title,
                style: TextStyle(
                  color: style.foregroundColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom bar with a secondary (text) action and a primary (filled) action.
/// Honors [PaperScannerStyle.actionButtonBuilder] for the primary action.
class ScannerBottomActionBar extends StatelessWidget {
  const ScannerBottomActionBar({
    super.key,
    required this.style,
    required this.primaryLabel,
    required this.onPrimary,
    this.busy = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  final PaperScannerStyle style;
  final bool busy;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Row(
          mainAxisAlignment: secondaryLabel != null
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.end,
          children: [
            if (secondaryLabel != null)
              TextButton(
                onPressed: busy ? null : onSecondary,
                child: Text(
                  secondaryLabel!,
                  style: TextStyle(color: style.foregroundColor, fontSize: 16),
                ),
              ),
            if (style.actionButtonBuilder != null)
              style.actionButtonBuilder!(context, primaryLabel, onPrimary)
            else
              ElevatedButton(
                onPressed: onPrimary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: style.accentColor,
                  foregroundColor: style.onAccentColor,
                  disabledBackgroundColor: style.accentColor.withValues(
                    alpha: 0.4,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: style.onAccentColor,
                        ),
                      )
                    : Text(primaryLabel, style: const TextStyle(fontSize: 16)),
              ),
          ],
        ),
      ),
    );
  }
}
