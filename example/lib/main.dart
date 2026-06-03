import 'dart:io';

import 'package:flutter/material.dart';
import 'package:paper_scanner/paper_scanner.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'paper_scanner demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PaperScanResult? _result;
  String? _error;

  Future<void> _scan(PaperScannerStyle style) async {
    setState(() => _error = null);
    try {
      final result = await PaperScanner.open(
        context,
        options: const PaperScannerOptions(outputPdf: true),
        style: style,
      );
      if (!mounted) return;
      setState(() => _result = result ?? _result);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// A heavily restyled scanner — the payoff system scanners can't offer.
  PaperScannerStyle get _customStyle => const PaperScannerStyle(
        backgroundColor: Color(0xFF0E1B16),
        surfaceColor: Color(0xFF13261F),
        accentColor: Color(0xFF1B998B),
        overlayStrokeWidth: 4,
        cornerHandleRadius: 16,
        labels: PaperScannerLabels(
          readyForNextScan: 'Ready for the next page.',
          cropTitle: 'Line up the edges',
          retake: 'Redo',
          keep: 'Keep',
          done: 'Finish',
        ),
      );

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('paper_scanner demo')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Launch the fully custom document scanner. Detection runs on '
            'Vision (iOS) / OpenCV (Android); the UI is pure Flutter.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _scan(const PaperScannerStyle()),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scan (default style)'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => _scan(_customStyle),
            icon: const Icon(Icons.palette_outlined),
            label: const Text('Scan (custom theme)'),
          ),
          const SizedBox(height: 24),
          if (_error != null)
            Text('Error: $_error', style: const TextStyle(color: Colors.red)),
          if (result != null) ...[
            Text('Pages: ${result.pageCount}',
                style: Theme.of(context).textTheme.titleMedium),
            if (result.pdfPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('PDF: ${result.pdfPath}'),
              ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final path in result.imagePaths)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(path), fit: BoxFit.cover),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
