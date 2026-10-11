import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.pdfBytes,
    required this.fileName,
  });

  final String title;
  final Uint8List pdfBytes;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Document',
            onPressed: () async {
              await Printing.sharePdf(
                bytes: pdfBytes,
                filename: fileName,
              );
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => pdfBytes,
        pdfFileName: fileName,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        initialPageFormat: PdfPageFormat.a4,
        loadingWidget: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
