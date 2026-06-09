import 'dart:typed_data';
import 'dart:ui' show Offset;

/// A normalized 2D point.
///
/// Both [x] and [y] are expressed as a fraction of the source image's width and
/// height respectively, so the value is resolution-independent and always in
/// the range `0.0 .. 1.0`. The origin `(0, 0)` is the **top-left** corner of
/// the image (matching Flutter's coordinate system). Platform implementations
/// are responsible for converting to/from their native coordinate spaces (for
/// example Vision uses a bottom-left origin and must flip `y`).
class ScanPoint {
  /// Creates a normalized point. Values are stored as-is; use [clamped] to keep
  /// them inside the unit square.
  const ScanPoint(this.x, this.y);

  /// Builds a [ScanPoint] from a Flutter [Offset] that already holds normalized
  /// coordinates.
  factory ScanPoint.fromOffset(Offset offset) =>
      ScanPoint(offset.dx, offset.dy);

  /// Normalized horizontal position, `0.0` (left) .. `1.0` (right).
  final double x;

  /// Normalized vertical position, `0.0` (top) .. `1.0` (bottom).
  final double y;

  /// This point as a Flutter [Offset] (still normalized).
  Offset toOffset() => Offset(x, y);

  /// A copy with both axes constrained to `0.0 .. 1.0`.
  ScanPoint get clamped => ScanPoint(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));

  /// Returns a copy translated by the given normalized delta.
  ScanPoint translate(double dx, double dy) => ScanPoint(x + dx, y + dy);

  @override
  String toString() =>
      'ScanPoint(${x.toStringAsFixed(4)}, ${y.toStringAsFixed(4)})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Four normalized corner points describing a document outline.
///
/// Corners are stored in a fixed order — [topLeft], [topRight], [bottomRight],
/// [bottomLeft] — which both native sides rely on when serializing over the
/// channel and when applying the perspective transform.
class Quad {
  /// Creates a quad from four explicit corners.
  const Quad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  /// A quad covering the entire frame (the sensible default when detection
  /// fails and the user must adjust corners manually).
  factory Quad.full() => const Quad(
    topLeft: ScanPoint(0, 0),
    topRight: ScanPoint(1, 0),
    bottomRight: ScanPoint(1, 1),
    bottomLeft: ScanPoint(0, 1),
  );

  /// Reconstructs a quad from a flat list of 8 doubles in corner order:
  /// `[tlX, tlY, trX, trY, brX, brY, blX, blY]`.
  factory Quad.fromList(List<Object?> raw) {
    final v = raw.map((e) => (e as num).toDouble()).toList(growable: false);
    assert(v.length == 8, 'A quad requires exactly 8 values, got ${v.length}');
    return Quad(
      topLeft: ScanPoint(v[0], v[1]),
      topRight: ScanPoint(v[2], v[3]),
      bottomRight: ScanPoint(v[4], v[5]),
      bottomLeft: ScanPoint(v[6], v[7]),
    );
  }

  final ScanPoint topLeft;
  final ScanPoint topRight;
  final ScanPoint bottomRight;
  final ScanPoint bottomLeft;

  /// The four corners in serialization order.
  List<ScanPoint> get corners => [topLeft, topRight, bottomRight, bottomLeft];

  /// Flattens the quad to `[tlX, tlY, trX, trY, brX, brY, blX, blY]` for the
  /// platform channel.
  List<double> toList() => [
    topLeft.x,
    topLeft.y,
    topRight.x,
    topRight.y,
    bottomRight.x,
    bottomRight.y,
    bottomLeft.x,
    bottomLeft.y,
  ];

  /// Returns a copy with every corner clamped to the unit square.
  Quad get clamped => Quad(
    topLeft: topLeft.clamped,
    topRight: topRight.clamped,
    bottomRight: bottomRight.clamped,
    bottomLeft: bottomLeft.clamped,
  );

  /// Replaces a single corner, identified by its index in [corners]
  /// (0 = TL, 1 = TR, 2 = BR, 3 = BL).
  Quad copyWithCorner(int index, ScanPoint point) => Quad(
    topLeft: index == 0 ? point : topLeft,
    topRight: index == 1 ? point : topRight,
    bottomRight: index == 2 ? point : bottomRight,
    bottomLeft: index == 3 ? point : bottomLeft,
  );

  @override
  String toString() => 'Quad($topLeft, $topRight, $bottomRight, $bottomLeft)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Quad &&
          other.topLeft == topLeft &&
          other.topRight == topRight &&
          other.bottomRight == bottomRight &&
          other.bottomLeft == bottomLeft;

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);
}

/// The result of a detection request: a [Quad] plus a `0.0 .. 1.0` [confidence]
/// score reported by the native detector.
class DetectedQuad {
  const DetectedQuad({required this.quad, this.confidence = 0});

  /// Parses the map returned by the platform channel:
  /// `{ 'corners': List<double>(8), 'confidence': double }`.
  factory DetectedQuad.fromMap(Map<Object?, Object?> map) => DetectedQuad(
    quad: Quad.fromList(map['corners']! as List<Object?>),
    confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
  );

  final Quad quad;
  final double confidence;

  Map<String, Object?> toMap() => {
    'corners': quad.toList(),
    'confidence': confidence,
  };

  @override
  String toString() =>
      'DetectedQuad($quad, confidence: ${confidence.toStringAsFixed(2)})';
}

/// Enhancement filters applied to a captured page.
enum ScanFilter {
  /// No processing — the original capture.
  original('original'),

  /// Auto contrast/brightness/saturation boost for color documents.
  enhance('enhance'),

  /// Desaturated grayscale.
  grayscale('grayscale'),

  /// High-contrast bilevel ("scanner") look via adaptive thresholding.
  blackWhite('blackWhite');

  const ScanFilter(this.wireName);

  /// Stable identifier sent across the platform channel. Decoupled from
  /// [Enum.name] so renames never break the native contract.
  final String wireName;
}

/// The pixel format of a [FrameData] buffer streamed from the camera preview.
enum FrameFormat {
  /// Android camera stream: planar YUV. Only the Y (luminance) plane is sent,
  /// which is all the edge detector needs.
  yuv420('yuv420'),

  /// iOS camera stream: interleaved 8-bit BGRA, 4 bytes per pixel.
  bgra8888('bgra8888');

  const FrameFormat(this.wireName);

  final String wireName;
}

/// A single, already-downscaled preview frame handed to [detectInFrame]-style
/// realtime detection.
///
/// To keep the channel cheap the UI sends **luminance only** for YUV streams
/// (the first plane), since edge/rectangle detection does not need color.
/// [bytesPerRow] carries the plane's row stride, which can exceed [width] due
/// to hardware alignment padding; native code must honor it.
class FrameData {
  const FrameData({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.rotation,
    required this.format,
  });

  /// Raw plane bytes (Y plane for [FrameFormat.yuv420], BGRA for
  /// [FrameFormat.bgra8888]).
  final Uint8List bytes;

  /// Frame width in pixels.
  final int width;

  /// Frame height in pixels.
  final int height;

  /// Row stride of [bytes] in bytes; `>= width` (YUV) or `>= width * 4` (BGRA).
  final int bytesPerRow;

  /// Clockwise rotation in degrees (0, 90, 180, 270) needed to display upright.
  final int rotation;

  /// Pixel layout of [bytes].
  final FrameFormat format;

  /// Serializes for the platform channel.
  Map<String, Object?> toMap() => {
    'bytes': bytes,
    'width': width,
    'height': height,
    'bytesPerRow': bytesPerRow,
    'rotation': rotation,
    'format': format.wireName,
  };
}
