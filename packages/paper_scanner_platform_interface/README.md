# paper_scanner_platform_interface

The common platform interface for the [`paper_scanner`][app] federated plugin.

Apps should depend on **`paper_scanner`**, not this package. Implement this
interface only if you are writing a new platform implementation.

## The contract

`PaperScannerPlatform` defines four operations:

| Method | Purpose |
|--------|---------|
| `detectInImage(path)` | Detect the document quad in a captured still. |
| `detectInFrame(frame)` | Realtime detection on a downscaled preview frame. |
| `cropPerspective(path, quad)` | Warp the four corners to a flat rectangle. |
| `applyFilter(path, filter)` | Enhance / grayscale / black-and-white. |

Coordinates are **normalized** (`0..1`, top-left origin) and quads are ordered
TL, TR, BR, BL.

### Channel

The default implementation, `MethodChannelPaperScanner`, talks over the
`paper_scanner` [`MethodChannel`]. Native packages register a handler on that
same channel name, so the bundled Android/iOS implementations need no extra
Dart registration.

## Pigeon migration

A typed equivalent of the channel lives in [`pigeons/messages.dart`](pigeons/messages.dart).
To switch to generated code:

```bash
dart run pigeon --input pigeons/messages.dart
```

This emits `lib/src/messages.g.dart` plus `Messages.g.kt` / `Messages.g.swift`
in the implementation packages. Then route `MethodChannelPaperScanner` through
the generated `PaperScannerApi` and implement the generated host interfaces
natively. The hand-authored channel is shipped by default so the package builds
without running codegen.

[app]: https://pub.dev/packages/paper_scanner
[`MethodChannel`]: https://api.flutter.dev/flutter/services/MethodChannel-class.html
