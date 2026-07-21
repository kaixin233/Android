import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

import '../data/textbooks.dart';

/// 内嵌 PDF 阅读器
class PdfReaderPage extends StatefulWidget {
  final Textbook textbook;

  const PdfReaderPage({super.key, required this.textbook});

  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  String? _error;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final assetPath = 'PDF/${widget.textbook.fileName}';
      final data = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${widget.textbook.fileName}');
      await tempFile.writeAsBytes(data.buffer.asUint8List());
      setState(() {
        _filePath = tempFile.path;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.textbook.title),
        centerTitle: false,
        actions: [
          if (_isReady)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Text(_error!, style: theme.textTheme.bodyLarge),
                ],
              ),
            )
          : _filePath == null
              ? const Center(child: CircularProgressIndicator())
              : PDFView(
                  filePath: _filePath!,
                  enableSwipe: true,
                  swipeHorizontal: false,
                  autoSpacing: true,
                  pageFling: true,
                  onRender: (pages) {
                    setState(() {
                      _totalPages = pages ?? 0;
                      _isReady = true;
                    });
                  },
                  onPageChanged: (page, _) {
                    setState(() => _currentPage = page ?? 0);
                  },
                  onError: (error) {
                    setState(() => _error = error.toString());
                  },
                ),
    );
  }
}