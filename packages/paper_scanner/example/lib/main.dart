import 'dart:io';
import 'package:flutter/material.dart';
import 'package:paper_document_scanner/paper_document_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paper Scanner Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  PaperScanResult? _scanResult;

  Future<void> _scanDocument() async {
    final result = await PaperScanner.open(
      context,
      options: const PaperScannerOptions(outputPdf: true),
    );
    if (result != null) {
      setState(() {
        _scanResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: _scanResult == null
            ? const Text('Tap the button to scan a document')
            : ListView.builder(
                itemCount: _scanResult!.imagePaths.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.file(File(_scanResult!.imagePaths[index])),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanDocument,
        tooltip: 'Scan Document',
        child: const Icon(Icons.document_scanner),
      ),
    );
  }
}
