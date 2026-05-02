import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xloop_invoice/core/utils/share_helper.dart';
import 'package:url_launcher/url_launcher.dart';

// Conditional imports for web platform view
import 'document_viewer_stub.dart'
    if (dart.library.html) 'document_viewer_web.dart'
    as platform_viewer;

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
    final cleanUrl = url.split('?').first.toLowerCase();
    if (cleanUrl.endsWith('.pdf')) {
      return true;
    }
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
            icon: const Icon(Icons.download),
            onPressed: () async {
              final uri = Uri.parse(widget.attachmentUrl);
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not download file')),
                  );
                }
              }
            },
            tooltip: 'Download',
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
              ? _buildPdfViewer()
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

  Widget _buildPdfViewer() {
    if (kIsWeb) {
      // On web, use an iframe to leverage the browser's built-in PDF viewer.
      // This avoids CORS and binary data corruption issues entirely.
      return platform_viewer.buildPdfWebView(widget.attachmentUrl);
    }

    // On native platforms, use SfPdfViewer.network directly (no CORS issues).
    return SfPdfViewer.network(
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
              content: Text('Failed to load PDF: ${details.error}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
    );
  }
}
