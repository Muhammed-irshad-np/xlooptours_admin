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
    // Always try to fetch Storage metadata — we use it both for type detection
    // on extensionless files AND for a proper download filename.
    // Skip only if the URL is obviously not a Firebase Storage URL.
    _maybeInitMetadata();
  }

  void _maybeInitMetadata() {
    final ext = _getExtension(widget.attachmentUrl);
    // If extension is unrecognised (including false-positives like '.com' from
    // the bucket name), fetch Storage metadata to determine the real type.
    if (!_isKnownExtension(ext)) {
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

  /// Extracts the file extension from the **filename portion** of a Firebase
  /// Storage URL.
  ///
  /// Firebase Storage download URLs have the form:
  ///   https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<encoded-path>?...
  ///
  /// The bucket name often contains dots (e.g. `myapp.appspot.com`), so we
  /// must NOT search the whole URL path — only the last segment after the
  /// final `/` in the decoded object path.
  String _getExtension(String url) {
    try {
      final uri = Uri.parse(url);
      // The object path lives after `/o/` in the URL path.
      // uri.path example: /v0/b/myapp.appspot.com/o/vault%2Ffolder%2Ffile.pdf
      final rawPath = uri.path;
      final oIndex = rawPath.indexOf('/o/');
      final objectEncoded = oIndex != -1
          ? rawPath.substring(oIndex + 3) // everything after '/o/'
          : rawPath;

      // Decode percent-encoding (e.g. %2F → /, %20 → space)
      final objectDecoded = Uri.decodeComponent(objectEncoded);

      // Get the last path segment (the actual filename) — ignore folder names.
      final segments = objectDecoded.split('/');
      final filename = segments.last.split('?').first; // strip any trailing query

      final dotIndex = filename.lastIndexOf('.');
      if (dotIndex != -1 && dotIndex < filename.length - 1) {
        return filename.substring(dotIndex).toLowerCase();
      }
    } catch (_) {}
    return '';
  }

  /// Returns true if [ext] is one of the extensions the viewer can handle.
  bool _isKnownExtension(String ext) {
    const known = {
      '.pdf',
      '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp',
      '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
      '.rtf', '.csv', '.txt',
    };
    return known.contains(ext);
  }

  /// Returns the extension that corresponds to a MIME content type.
  String _extensionFromMime(String mime) {
    switch (mime) {
      case 'application/pdf': return '.pdf';
      case 'image/jpeg': return '.jpg';
      case 'image/png': return '.png';
      case 'image/gif': return '.gif';
      case 'image/webp': return '.webp';
      case 'application/msword': return '.doc';
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document': return '.docx';
      case 'application/vnd.ms-excel': return '.xls';
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': return '.xlsx';
      case 'application/vnd.ms-powerpoint': return '.ppt';
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation': return '.pptx';
      case 'text/csv': return '.csv';
      case 'text/plain': return '.txt';
      default: return '';
    }
  }

  /// Determines if this document is a PDF.
  bool get _isPdf {
    final ext = _getExtension(widget.attachmentUrl);
    if (ext == '.pdf') return true;
    if (!_isKnownExtension(ext) && _resolvedContentType != null) {
      return _resolvedContentType!.contains('pdf');
    }
    return false;
  }

  /// Determines if this document is an image.
  bool get _isImage {
    const imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};
    final ext = _getExtension(widget.attachmentUrl);
    if (imageExtensions.contains(ext)) return true;
    if (!_isKnownExtension(ext) && _resolvedContentType != null) {
      return _resolvedContentType!.startsWith('image/');
    }
    return false;
  }

  /// Determines if this document is an Office document.
  bool get _isOfficeDoc {
    final ext = _getExtension(widget.attachmentUrl);
    if (_officeExtensions.contains(ext)) return true;
    if (!_isKnownExtension(ext) && _resolvedContentType != null) {
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

  /// Opens the document in an external browser for download.
  ///
  /// If we resolved metadata (e.g. for an extensionless file), we inform the
  /// user of the correct file extension so they know which app to open it with.
  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.attachmentUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document link')),
        );
      }
      return;
    }
    // If the file was extensionless, show a hint about the extension so the
    // user knows to rename it after download.
    if (mounted && _resolvedContentType != null && _resolvedContentType!.isNotEmpty) {
      final hint = _extensionFromMime(_resolvedContentType!);
      if (hint.isNotEmpty) {
        final ext = _getExtension(widget.attachmentUrl);
        if (!_isKnownExtension(ext)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tip: add "$hint" to the filename after download (e.g. ${widget.title}$hint)',
              ),
              duration: const Duration(seconds: 6),
              backgroundColor: Colors.blue.shade700,
            ),
          );
        }
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
