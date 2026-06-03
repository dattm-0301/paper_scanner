import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paper_scanner_platform_interface/paper_scanner_platform_interface.dart';

import 'paper_scan_result.dart';
import 'paper_scanner_controller.dart';

/// Builds the capture (shutter) button. [onCapture] takes the photo; [busy] is
/// true while a capture/processing step is running.
typedef CaptureButtonBuilder =
    Widget Function(BuildContext context, VoidCallback onCapture, bool busy);

/// Builds the camera top chrome. Return a full replacement for the
/// close/status/done row.
typedef CameraTopChromeBuilder =
    Widget Function(
      BuildContext context,
      PaperScannerController controller,
      PaperScannerStyle style,
      VoidCallback onCancel,
      VoidCallback onDone,
    );

/// Builds the camera bottom chrome. Return a full replacement for controls,
/// thumbnail preview and shutter.
typedef CameraBottomChromeBuilder =
    Widget Function(
      BuildContext context,
      PaperScannerController controller,
      PaperScannerStyle style,
      VoidCallback onCapture,
      VoidCallback onReview,
      VoidCallback onCycleFlash,
      VoidCallback onOpenFilters,
      VoidCallback onToggleAutoCapture,
      bool capturing,
      IconData flashIcon,
    );

/// Builds a status pill such as "Ready for next scan.".
typedef StatusPillBuilder =
    Widget Function(
      BuildContext context,
      String label,
      PaperScannerStyle style,
    );

/// Builds a round top icon button such as close or done.
typedef ScannerIconButtonBuilder =
    Widget Function(
      BuildContext context,
      IconData icon,
      VoidCallback onTap,
      Color background,
      Color foreground,
    );

/// Builds one camera control button (Flash, Filters, Shutter auto toggle).
typedef ScannerControlButtonBuilder =
    Widget Function(
      BuildContext context,
      IconData icon,
      String label,
      VoidCallback onTap,
      bool active,
      PaperScannerStyle style,
    );

/// Builds the committed-page preview thumbnail shown in the camera stage.
typedef PageThumbnailBuilder =
    Widget Function(
      BuildContext context,
      ScannedPage page,
      VoidCallback onTap,
      PaperScannerStyle style,
    );

/// Builds a single draggable crop corner handle.
typedef CornerHandleBuilder = Widget Function(BuildContext context);

/// Builds a primary action button (e.g. "Keep") given a [label] and
/// [onPressed] (null = disabled).
typedef ActionButtonBuilder =
    Widget Function(
      BuildContext context,
      String label,
      VoidCallback? onPressed,
    );

/// Builds the crop/review action row. Return a full replacement for Retake/Keep.
typedef CropActionsBuilder =
    Widget Function(
      BuildContext context,
      PaperScannerController controller,
      PaperScannerStyle style,
      VoidCallback onRetake,
      VoidCallback onKeep,
    );

/// Builds one crop action button such as Retake or Keep.
typedef CropActionButtonBuilder =
    Widget Function(
      BuildContext context,
      String label,
      VoidCallback? onTap,
      bool primary,
      bool busy,
      PaperScannerStyle style,
    );

/// All user-facing strings, so consumers localize the scanner with their own
/// translations. Defaults match the reference design.
class PaperScannerLabels {
  const PaperScannerLabels({
    this.readyForNextScan = 'Bereit für den nächsten Scan.',
    this.cropTitle = 'Ecken anpassen',
    this.retake = 'Neu aufnehmen',
    this.keep = 'Behalten',
    this.done = 'Fertig',
    this.cancel = 'Abbrechen',
    this.review = 'Überprüfen',
    this.delete = 'Löschen',
    this.flash = 'Blitz',
    this.filters = 'Filter',
    this.autoShutter = 'Auslöser',
    this.filterOriginal = 'Original',
    this.filterEnhance = 'Verbessern',
    this.filterGrayscale = 'Graustufen',
    this.filterBlackWhite = 'S/W',
    this.cameraPermissionTitle = 'Kamerazugriff erforderlich',
    this.cameraPermissionMessage =
        'Erlaube den Kamerazugriff, um Dokumente zu scannen.',
    this.retryCamera = 'Erneut versuchen',
    this.pageCounter = 'Seite',
    this.processing = 'Wird verarbeitet...',
    this.maxPagesReached = 'Maximale Seitenanzahl erreicht',
  });

  static const PaperScannerLabels _german = PaperScannerLabels();

  static const PaperScannerLabels _english = PaperScannerLabels(
    readyForNextScan: 'Ready for next scan.',
    cropTitle: 'Adjust corners',
    retake: 'Retake',
    keep: 'Keep',
    done: 'Done',
    cancel: 'Cancel',
    review: 'Review',
    delete: 'Delete',
    flash: 'Flash',
    filters: 'Filters',
    autoShutter: 'Shutter',
    filterOriginal: 'Original',
    filterEnhance: 'Enhance',
    filterGrayscale: 'Grayscale',
    filterBlackWhite: 'B & W',
    cameraPermissionTitle: 'Camera access needed',
    cameraPermissionMessage: 'Allow camera access to scan documents.',
    retryCamera: 'Try again',
    pageCounter: 'Page',
    processing: 'Processing...',
    maxPagesReached: 'Maximum number of pages reached',
  );

  static const PaperScannerLabels _vietnamese = PaperScannerLabels(
    readyForNextScan: 'Sẵn sàng quét tiếp.',
    cropTitle: 'Chỉnh góc',
    retake: 'Chụp lại',
    keep: 'Giữ',
    done: 'Xong',
    cancel: 'Hủy',
    review: 'Xem lại',
    delete: 'Xóa',
    flash: 'Đèn',
    filters: 'Bộ lọc',
    autoShutter: 'Màn trập',
    filterOriginal: 'Gốc',
    filterEnhance: 'Nâng cao',
    filterGrayscale: 'Xám',
    filterBlackWhite: 'Đen trắng',
    cameraPermissionTitle: 'Cần quyền camera',
    cameraPermissionMessage: 'Cho phép truy cập camera để quét tài liệu.',
    retryCamera: 'Thử lại',
    pageCounter: 'Trang',
    processing: 'Đang xử lý...',
    maxPagesReached: 'Đã đạt số trang tối đa',
  );

  final String readyForNextScan;
  final String cropTitle;
  final String retake;
  final String keep;
  final String done;
  final String cancel;
  final String review;
  final String delete;
  final String flash;
  final String filters;
  final String autoShutter;
  final String filterOriginal;
  final String filterEnhance;
  final String filterGrayscale;
  final String filterBlackWhite;
  final String cameraPermissionTitle;
  final String cameraPermissionMessage;
  final String retryCamera;
  final String pageCounter;
  final String processing;
  final String maxPagesReached;

  /// The display label for a [ScanFilter].
  String filterName(ScanFilter filter) {
    switch (filter) {
      case ScanFilter.original:
        return filterOriginal;
      case ScanFilter.enhance:
        return filterEnhance;
      case ScanFilter.grayscale:
        return filterGrayscale;
      case ScanFilter.blackWhite:
        return filterBlackWhite;
    }
  }

  /// Returns built-in labels for [locale], preserving any custom labels that
  /// differ from the German defaults.
  PaperScannerLabels resolve(Locale locale) {
    final localized = switch (locale.languageCode.toLowerCase()) {
      'en' => _english,
      'vi' => _vietnamese,
      'de' => _german,
      _ => _german,
    };
    if (localized == _german) return this;
    return PaperScannerLabels(
      readyForNextScan: _localizedOrCustom(
        readyForNextScan,
        _german.readyForNextScan,
        localized.readyForNextScan,
      ),
      cropTitle: _localizedOrCustom(
        cropTitle,
        _german.cropTitle,
        localized.cropTitle,
      ),
      retake: _localizedOrCustom(retake, _german.retake, localized.retake),
      keep: _localizedOrCustom(keep, _german.keep, localized.keep),
      done: _localizedOrCustom(done, _german.done, localized.done),
      cancel: _localizedOrCustom(cancel, _german.cancel, localized.cancel),
      review: _localizedOrCustom(review, _german.review, localized.review),
      delete: _localizedOrCustom(delete, _german.delete, localized.delete),
      flash: _localizedOrCustom(flash, _german.flash, localized.flash),
      filters: _localizedOrCustom(filters, _german.filters, localized.filters),
      autoShutter: _localizedOrCustom(
        autoShutter,
        _german.autoShutter,
        localized.autoShutter,
      ),
      filterOriginal: _localizedOrCustom(
        filterOriginal,
        _german.filterOriginal,
        localized.filterOriginal,
      ),
      filterEnhance: _localizedOrCustom(
        filterEnhance,
        _german.filterEnhance,
        localized.filterEnhance,
      ),
      filterGrayscale: _localizedOrCustom(
        filterGrayscale,
        _german.filterGrayscale,
        localized.filterGrayscale,
      ),
      filterBlackWhite: _localizedOrCustom(
        filterBlackWhite,
        _german.filterBlackWhite,
        localized.filterBlackWhite,
      ),
      cameraPermissionTitle: _localizedOrCustom(
        cameraPermissionTitle,
        _german.cameraPermissionTitle,
        localized.cameraPermissionTitle,
      ),
      cameraPermissionMessage: _localizedOrCustom(
        cameraPermissionMessage,
        _german.cameraPermissionMessage,
        localized.cameraPermissionMessage,
      ),
      retryCamera: _localizedOrCustom(
        retryCamera,
        _german.retryCamera,
        localized.retryCamera,
      ),
      pageCounter: _localizedOrCustom(
        pageCounter,
        _german.pageCounter,
        localized.pageCounter,
      ),
      processing: _localizedOrCustom(
        processing,
        _german.processing,
        localized.processing,
      ),
      maxPagesReached: _localizedOrCustom(
        maxPagesReached,
        _german.maxPagesReached,
        localized.maxPagesReached,
      ),
    );
  }

  static String _localizedOrCustom(
    String current,
    String englishDefault,
    String localizedDefault,
  ) {
    return current == englishDefault ? localizedDefault : current;
  }
}

/// The full visual theme for the scanner UI — the custom-UI payoff that OS
/// system scanners cannot offer.
///
/// Defaults reproduce the reference design: an orange ([accentColor]) accent
/// for pills/primary actions, a blue ([overlayStrokeColor]) live edge overlay,
/// a blue ([confirmColor]) "done" check, a white ([shutterColor]) shutter and
/// white ring corner handles. Override any field, swap whole widgets via the
/// builder slots, or localize every string via [labels].
class PaperScannerStyle {
  const PaperScannerStyle({
    this.backgroundColor = Colors.black,
    this.surfaceColor = const Color(0xFF1C1C1E),
    this.accentColor = const Color(0xFFFF7900),
    this.onAccentColor = Colors.white,
    this.foregroundColor = Colors.white,
    this.confirmColor = const Color(0xFF35AAFF),
    this.shutterColor = Colors.white,
    this.overlayStrokeColor = const Color(0xFF2D9CFF),
    this.overlayFillColor,
    this.overlayStrokeWidth = 3.0,
    this.cornerHandleColor = Colors.white,
    this.cornerHandleRadius = 16.0,
    this.filterChipSelectedColor,
    this.labels = const PaperScannerLabels(),
    this.captureButtonBuilder,
    this.cameraTopChromeBuilder,
    this.cameraBottomChromeBuilder,
    this.statusPillBuilder,
    this.iconButtonBuilder,
    this.controlButtonBuilder,
    this.pageThumbnailBuilder,
    this.cornerHandleBuilder,
    this.actionButtonBuilder,
    this.cropActionsBuilder,
    this.cropActionButtonBuilder,
    this.statusPillTextStyle,
    this.controlLabelTextStyle,
    this.cropActionTextStyle,
    this.shutterBorderColor,
    this.shutterBorderWidth,
    this.thumbnailBorderColor,
    this.thumbnailBorderWidth,
    this.systemOverlayStyle,
  });

  /// Full-screen background (camera letterboxing, crop page).
  final Color backgroundColor;

  /// Color for bars, sheets and thumbnail strips.
  final Color surfaceColor;

  /// Primary accent — orange by default (status pill, "Keep", "Retake" text).
  final Color accentColor;

  /// Foreground used on top of [accentColor].
  final Color onAccentColor;

  /// Default text/icon color on [backgroundColor]/[surfaceColor].
  final Color foregroundColor;

  /// Color of the top-right "done" check button (blue by default).
  final Color confirmColor;

  /// Color of the shutter button (white by default).
  final Color shutterColor;

  /// Stroke of the live/crop quad outline (blue by default).
  final Color overlayStrokeColor;

  /// Translucent fill inside the detected quad. Defaults to transparent.
  final Color? overlayFillColor;

  /// Outline thickness for the quad overlay.
  final double overlayStrokeWidth;

  /// Color of the corner handle ring (white by default).
  final Color cornerHandleColor;

  /// Radius (logical px) of the default corner handle ring.
  final double cornerHandleRadius;

  /// Background of the selected filter chip. Defaults to [accentColor].
  final Color? filterChipSelectedColor;

  /// All localized strings.
  final PaperScannerLabels labels;

  /// Optional full replacement for the shutter button.
  final CaptureButtonBuilder? captureButtonBuilder;

  /// Optional full replacement for the camera top row.
  final CameraTopChromeBuilder? cameraTopChromeBuilder;

  /// Optional full replacement for the camera bottom controls.
  final CameraBottomChromeBuilder? cameraBottomChromeBuilder;

  /// Optional replacement for the orange status pill.
  final StatusPillBuilder? statusPillBuilder;

  /// Optional replacement for top icon buttons.
  final ScannerIconButtonBuilder? iconButtonBuilder;

  /// Optional replacement for camera control buttons.
  final ScannerControlButtonBuilder? controlButtonBuilder;

  /// Optional replacement for the bottom-left page preview thumbnail.
  final PageThumbnailBuilder? pageThumbnailBuilder;

  /// Optional full replacement for crop corner handles.
  final CornerHandleBuilder? cornerHandleBuilder;

  /// Optional full replacement for primary action buttons.
  final ActionButtonBuilder? actionButtonBuilder;

  /// Optional full replacement for the crop Retake / Keep action row.
  final CropActionsBuilder? cropActionsBuilder;

  /// Optional replacement for a crop action pill.
  final CropActionButtonBuilder? cropActionButtonBuilder;

  /// Optional text style override for the status pill.
  final TextStyle? statusPillTextStyle;

  /// Optional text style override for camera control labels.
  final TextStyle? controlLabelTextStyle;

  /// Optional text style override for crop action pills.
  final TextStyle? cropActionTextStyle;

  /// Optional shutter border color override.
  final Color? shutterBorderColor;

  /// Optional shutter border width override.
  final double? shutterBorderWidth;

  /// Optional thumbnail border color override.
  final Color? thumbnailBorderColor;

  /// Optional thumbnail border width override.
  final double? thumbnailBorderWidth;

  /// Status/navigation bar overlay style for the scanner route.
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// Effective overlay fill color (transparent when unset).
  Color get effectiveOverlayFill => overlayFillColor ?? Colors.transparent;

  /// Effective selected-chip color.
  Color get effectiveChipSelected => filterChipSelectedColor ?? accentColor;

  /// Labels resolved from the current Flutter locale.
  PaperScannerLabels labelsFor(BuildContext context) {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final appLocale = Localizations.maybeLocaleOf(context);
    final locale = deviceLocale.languageCode.isEmpty && appLocale != null
        ? appLocale
        : deviceLocale;
    return labels.resolve(locale);
  }
}
