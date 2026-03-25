import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xloop_invoice/core/utils/share_helper.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String attachmentUrl;
  final String title;

  const DocumentViewerScreen({
    super.key,
    required this.attachmentUrl,
    required this.title,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  bool _isPdfUrl(String url) {
    // Attempt basic parsing
    final cleanUrl = url.split('?').first.toLowerCase();
    if (cleanUrl.endsWith('.pdf')) {
      return true;
    }
    // If it's a firebase url and doesn't clearly end with jpg/png/jpeg, we can attempt PDF rendering or pass it to CachedNetworkImage which will fail if it's a PDF.
    // For simplicity, we check for .pdf.
    return cleanUrl.endsWith('.pdf') || url.toLowerCase().contains('.pdf?');
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = _isPdfUrl(widget.attachmentUrl);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ShareHelper.shareDocument(
                context,
                url: widget.attachmentUrl,
                title: widget.title,
              );
            },
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: isPdf
              ? SfPdfViewer.network(
                  widget.attachmentUrl,
                  canShowScrollHead: false,
                  canShowScrollStatus: false,
                  onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                    debugPrint(
                      'PDF Load Failed: ${details.error} - ${details.description}',
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to load PDF: ${details.error}\nThis might be a CORS issue on Web.',
                          ),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  },
                )
              : InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: widget.attachmentUrl,
                    placeholder: (context, url) =>
                        const CircularProgressIndicator(),
                    errorWidget: (context, url, error) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 50),
                        SizedBox(height: 10),
                        Text(
                          'Failed to load image or this might be a PDF without .pdf extension',
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
