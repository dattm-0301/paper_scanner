import 'package:flutter/foundation.dart';

/// Debug-only logger for the scanner.
///
/// Guarded by [kDebugMode] so nothing is printed in profile/release builds —
/// matching common app logging hygiene. Logs metadata only; never log image
/// bytes or file contents.
void scannerLog(String message) {
  if (kDebugMode) {
    debugPrint('[paper_scanner] $message');
  }
}
