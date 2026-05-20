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
    return cleanUrl.endsWith('.pdf') || url.toLowerCase().contains('.pdf?');
  }

  bool _isImageUrl(String url) {
    final cleanUrl = url.split('?').first.toLowerCase();
    return cleanUrl.endsWith('.jpg') ||
        cleanUrl.endsWith('.jpeg') ||
        cleanUrl.endsWith('.png') ||
        cleanUrl.endsWith('.gif') ||
        cleanUrl.endsWith('.webp') ||
        url.toLowerCase().contains('.jpg?') ||
        url.toLowerCase().contains('.jpeg?') ||
        url.toLowerCase().contains('.png?') ||
        url.toLowerCase().contains('.gif?') ||
        url.toLowerCase().contains('.webp?');
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.attachmentUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document link')),
        );
      }
    }
  }

  Widget _buildFallbackView(String message) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.insert_drive_file_outlined,
              color: Colors.blue.shade700,
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open / Download Document'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    if (kIsWeb) {
      return InteractiveViewer(
        panEnabled: true,
        boundaryMargin: const EdgeInsets.all(20),
        minScale: 0.5,
        maxScale: 4,
        child: Image.network(
          widget.attachmentUrl,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackView(
              'Failed to load image on Web due to CORS restriction. You can view or download it directly.',
            );
          },
        ),
      );
    }

    return InteractiveViewer(
      panEnabled: true,
      boundaryMargin: const EdgeInsets.all(20),
      minScale: 0.5,
      maxScale: 4,
      child: CachedNetworkImage(
        imageUrl: widget.attachmentUrl,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) {
          return _buildFallbackView('Failed to load image. You can view or download it directly.');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = _isPdfUrl(widget.attachmentUrl);
    final isImage = _isImageUrl(widget.attachmentUrl);

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
            onPressed: _openInBrowser,
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
              : (isImage
                  ? _buildImageViewer()
                  : _buildFallbackView('This document format cannot be previewed inline.')),
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
