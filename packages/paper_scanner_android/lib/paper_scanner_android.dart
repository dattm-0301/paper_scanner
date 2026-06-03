/// The Android implementation of `paper_scanner`.
///
/// This package contains no public Dart API. Detection, perspective crop and
/// filtering are implemented natively in Kotlin + OpenCV
/// (`PaperScannerAndroidPlugin`), reached through the shared `paper_scanner`
/// [MethodChannel] that `MethodChannelPaperScanner` (in
/// `paper_scanner_platform_interface`) drives. Registration is declared in
/// `pubspec.yaml` via `flutter.plugin.platforms.android.pluginClass`.
library paper_scanner_android;
