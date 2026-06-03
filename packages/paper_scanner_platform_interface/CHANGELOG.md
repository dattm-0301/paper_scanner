## 0.1.0

* Initial release.
* `PaperScannerPlatform` with `detectInImage`, `detectInFrame`,
  `cropPerspective`, `applyFilter`.
* `MethodChannelPaperScanner` default implementation on the `paper_scanner`
  channel.
* Models: `ScanPoint`, `Quad`, `DetectedQuad`, `ScanFilter`, `FrameData`,
  `FrameFormat`.
* Pigeon definition (`pigeons/messages.dart`) for the optional typed-channel
  migration path.
