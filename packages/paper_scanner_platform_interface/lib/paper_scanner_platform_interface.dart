/// Platform interface for the `paper_scanner` federated plugin.
///
/// Consumers normally depend on the app-facing `paper_scanner` package rather
/// than this one directly. Alternate platform implementations import it to
/// extend [PaperScannerPlatform].
library paper_scanner_platform_interface;

export 'src/method_channel_paper_scanner.dart';
export 'src/models.dart';
export 'src/paper_scanner_platform.dart';
