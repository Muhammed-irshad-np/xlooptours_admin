import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xloop_invoice/core/utils/share_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  /// Office document file extensions supported by Google Docs Viewer.
  static const _officeExtensions = {
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.rtf',
    '.csv',
    '.txt',
  };

  /// Tracks the resolved content type fetched from Firebase Storage metadata.
  /// `null` means we haven't resolved it yet; empty string means fetch failed.
  String? _resolvedContentType;

  /// Whether we are currently fetching the Storage metadata for a URL
  /// whose extension cannot be determined from the URL alone.
  bool _fetchingMetadata = false;

  @override
  void initState() {
    super.initState();
    // If the URL has no recognisable extension, fetch metadata from Firebase Storage.
    final ext = _getExtension(widget.attachmentUrl);
    if (ext.isEmpty) {
      _fetchStorageMetadata();
    }
  }

  /// Attempts to resolve the file's MIME type by reading its Firebase Storage metadata.
  ///
  /// Falls back gracefully to the "unknown format" fallback view if the fetch fails,
  /// so existing corrupted/extensionless files still show a usable UI.
  Future<void> _fetchStorageMetadata() async {
    if (!mounted) return;
    setState(() => _fetchingMetadata = true);

    try {
      // Firebase Storage download URLs contain the object path encoded after
      // "/o/" in the URL.  Parse that to get a storage reference.
      final uri = Uri.parse(widget.attachmentUrl);
      // Typical Firebase Storage URL format:
      // https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<encoded-path>?...
      final pathSegments = uri.pathSegments;
      // pathSegments: ['v0', 'b', '<bucket>', 'o', '<encoded-path>']
      if (pathSegments.length >= 5 && pathSegments[3] == 'o') {
        // The encoded path is everything after '/o/' up to the '?' query.
        final encodedObjectPath = uri.path.split('/o/').last;
        final objectPath = Uri.decodeComponent(encodedObjectPath);
        final ref = FirebaseStorage.instance.ref(objectPath);
        final meta = await ref.getMetadata();
        final contentType = meta.contentType ?? '';
        if (mounted) {
          setState(() {
            _resolvedContentType = contentType;
            _fetchingMetadata = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('DocumentViewer: metadata fetch failed: $e');
    }

    if (mounted) {
      setState(() {
        _resolvedContentType = '';
        _fetchingMetadata = false;
      });
    }
  }

  /// Extracts the file extension from a Firebase Storage URL.
  ///
  /// Firebase encodes filenames in the path segment, so we URL-decode before
  /// extracting the extension to handle names like `Insurance%20Policy.docx`.
  String _getExtension(String url) {
    try {
      final uri = Uri.parse(url);
      // Decode the path to handle URL-encoded filenames
      final decodedPath = Uri.decodeFull(uri.path);
      // Remove query parameters and get the extension
      final cleanPath = decodedPath.split('?').first;
      final dotIndex = cleanPath.lastIndexOf('.');
      if (dotIndex != -1) {
        return cleanPath.substring(dotIndex).toLowerCase();
      }
    } catch (_) {}
    return '';
  }

  /// Determines if this document is a PDF, considering both URL extension
  /// and resolved Storage contentType for extensionless files.
  bool get _isPdf {
    final ext = _getExtension(widget.attachmentUrl);
    if (ext == '.pdf') return true;
    if (ext.isEmpty && _resolvedContentType != null) {
      return _resolvedContentType!.contains('pdf');
    }
    return false;
  }

  /// Determines if this document is an image.
  bool get _isImage {
    const imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};
    final ext = _getExtension(widget.attachmentUrl);
    if (imageExtensions.contains(ext)) return true;
    if (ext.isEmpty && _resolvedContentType != null) {
      return _resolvedContentType!.startsWith('image/');
    }
    return false;
  }

  /// Determines if this document is an Office document.
  bool get _isOfficeDoc {
    final ext = _getExtension(widget.attachmentUrl);
    if (_officeExtensions.contains(ext)) return true;
    if (ext.isEmpty && _resolvedContentType != null) {
      const officeMimeTypes = {
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'text/csv',
        'text/plain',
        'application/rtf',
      };
      return officeMimeTypes.contains(_resolvedContentType);
    }
    return false;
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
          return _buildFallbackView(
            'Failed to load image. You can view or download it directly.',
          );
        },
      ),
    );
  }

  /// Builds a viewer for office documents (Word, Excel, PowerPoint, etc.)
  /// using Google Docs Viewer.
  ///
  /// On web, uses an iframe. On native, uses a WebView widget.
  Widget _buildOfficeDocViewer() {
    if (kIsWeb) {
      return platform_viewer.buildOfficeDocWebView(widget.attachmentUrl);
    }

    // On native platforms, use WebViewWidget with Google Docs Viewer
    final encodedUrl = Uri.encodeComponent(widget.attachmentUrl);
    final viewerUrl =
        'https://docs.google.com/gview?embedded=true&url=$encodedUrl';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            debugPrint('Office doc viewer: page started loading');
          },
          onWebResourceError: (error) {
            debugPrint(
              'Office doc viewer error: ${error.description} (${error.errorCode})',
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(viewerUrl));

    return WebViewWidget(controller: controller);
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading spinner while we fetch metadata for extensionless files.
    if (_fetchingMetadata) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Detecting document type…'),
            ],
          ),
        ),
      );
    }

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
          child: _isPdf
              ? _buildPdfViewer()
              : _isImage
                  ? _buildImageViewer()
                  : _isOfficeDoc
                      ? _buildOfficeDocViewer()
                      : _buildFallbackView(
                          'This document format is not recognized. '
                          'You can download or open it in an external app.',
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
