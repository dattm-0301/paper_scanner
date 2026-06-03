/// The iOS implementation of `paper_scanner`.
///
/// This package contains no public Dart API. Detection (Apple Vision),
/// perspective crop and filters (CoreImage) are implemented natively in Swift
/// (`PaperScannerIosPlugin`), reached through the shared `paper_scanner`
/// method channel that `MethodChannelPaperScanner` (in
/// `paper_scanner_platform_interface`) drives. Registration is declared in
/// `pubspec.yaml` via `flutter.plugin.platforms.ios.pluginClass`.
library paper_scanner_ios;
