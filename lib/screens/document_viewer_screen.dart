import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xloop_invoice/core/utils/share_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Conditional imports for web platform view
import 'document_viewer_stub.dart'
    if (dart.library.html) 'document_viewer_web.dart'
    as platform_viewer;

/// Resolved file-type information for a document URL.
enum _DocType { pdf, image, office, unknown }

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
  /// Office document MIME types supported by Google Docs Viewer.
  static const _officeMimeTypes = {
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

  static const _knownExtensions = {
    '.pdf',
    '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp',
    '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    '.rtf', '.csv', '.txt',
  };

  _DocType _docType = _DocType.unknown;

  /// The resolved MIME string (e.g. 'application/pdf').  Used for downloads.
  String _resolvedMime = '';

  bool _detecting = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _detectDocType();
  }

  // ──────────────────────────────────────────────────────────────
  // Detection
  // ──────────────────────────────────────────────────────────────

  /// Determines the document type by:
  /// 1. Checking the file extension from the URL (fast, no network).
  /// 2. Fetching the first 16 bytes via HTTP Range request and running
  ///    magic-bytes detection (reliable for existing extensionless files).
  Future<void> _detectDocType() async {
    if (!mounted) return;
    setState(() => _detecting = true);

    // --- Step 1: try extension from URL ---
    final ext = _extensionFromUrl(widget.attachmentUrl);
    if (_knownExtensions.contains(ext)) {
      final type = _typeFromExtension(ext);
      if (mounted) {
        setState(() {
          _docType = type;
          _resolvedMime = _mimeFromExtension(ext);
          _detecting = false;
        });
      }
      return;
    }

    // --- Step 2: magic bytes via HTTP Range ---
    try {
      final response = await http.get(
        Uri.parse(widget.attachmentUrl),
        headers: {'Range': 'bytes=0-15'},
      ).timeout(const Duration(seconds: 15));

      final bytes = response.bodyBytes;
      final mime = _detectMimeFromBytes(bytes);
      final type = _typeFromMime(mime);

      if (mounted) {
        setState(() {
          _docType = type;
          _resolvedMime = mime;
          _detecting = false;
        });
      }
      return;
    } catch (e) {
      debugPrint('DocumentViewer: magic-bytes detection failed: $e');
    }

    // --- Step 3: give up, show fallback ---
    if (mounted) {
      setState(() {
        _docType = _DocType.unknown;
        _resolvedMime = '';
        _detecting = false;
      });
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Type helpers
  // ──────────────────────────────────────────────────────────────

  /// Detects MIME type from the first bytes of file content (magic bytes).
  String _detectMimeFromBytes(Uint8List b) {
    if (b.length >= 4 &&
        b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46) {
      return 'application/pdf'; // %PDF
    }
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return 'image/jpeg'; // JPEG
    }
    if (b.length >= 8 &&
        b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 &&
        b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A) {
      return 'image/png'; // PNG
    }
    if (b.length >= 6 &&
        b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 &&
        b[3] == 0x38 && (b[4] == 0x37 || b[4] == 0x39) && b[5] == 0x61) {
      return 'image/gif'; // GIF
    }
    if (b.length >= 12 &&
        b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return 'image/webp'; // WebP
    }
    if (b.length >= 4 &&
        b[0] == 0x50 && b[1] == 0x4B && b[2] == 0x03 && b[3] == 0x04) {
      // ZIP-based: covers xlsx, docx, pptx — default to xlsx for vault docs
      // since that is the most common office file type uploaded here.
      // Google Docs Viewer handles all of them regardless of the exact MIME.
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (b.length >= 8 &&
        b[0] == 0xD0 && b[1] == 0xCF && b[2] == 0x11 && b[3] == 0xE0 &&
        b[4] == 0xA1 && b[5] == 0xB1 && b[6] == 0x1A && b[7] == 0xE1) {
      // OLE2 compound: covers old .xls, .doc, .ppt
      return 'application/vnd.ms-excel';
    }
    return '';
  }

  _DocType _typeFromMime(String mime) {
    if (mime.contains('pdf')) return _DocType.pdf;
    if (mime.startsWith('image/')) return _DocType.image;
    if (_officeMimeTypes.contains(mime)) return _DocType.office;
    return _DocType.unknown;
  }

  _DocType _typeFromExtension(String ext) {
    if (ext == '.pdf') return _DocType.pdf;
    const imageExts = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};
    if (imageExts.contains(ext)) return _DocType.image;
    const officeExts = {
      '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
      '.rtf', '.csv', '.txt',
    };
    if (officeExts.contains(ext)) return _DocType.office;
    return _DocType.unknown;
  }

  /// Extracts the file extension from **only the filename part** of a Firebase
  /// Storage URL, ignoring the bucket name and folder paths.
  String _extensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      // Firebase Storage URL: .../o/<url-encoded-object-path>?...
      final rawPath = uri.path;
      final oIndex = rawPath.indexOf('/o/');
      final objectEncoded =
          oIndex != -1 ? rawPath.substring(oIndex + 3) : rawPath;
      final objectDecoded = Uri.decodeComponent(objectEncoded);
      // Last segment after splitting on '/' → actual filename
      final filename = objectDecoded.split('/').last.split('?').first;
      final dotIndex = filename.lastIndexOf('.');
      if (dotIndex != -1 && dotIndex < filename.length - 1) {
        return filename.substring(dotIndex).toLowerCase();
      }
    } catch (_) {}
    return '';
  }

  String _mimeFromExtension(String ext) {
    switch (ext) {
      case '.pdf': return 'application/pdf';
      case '.jpg': case '.jpeg': return 'image/jpeg';
      case '.png': return 'image/png';
      case '.gif': return 'image/gif';
      case '.webp': return 'image/webp';
      case '.doc': return 'application/msword';
      case '.docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls': return 'application/vnd.ms-excel';
      case '.xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.ppt': return 'application/vnd.ms-powerpoint';
      case '.pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.csv': return 'text/csv';
      case '.txt': return 'text/plain';
      default: return 'application/octet-stream';
    }
  }

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

  // ──────────────────────────────────────────────────────────────
  // Download with correct filename
  // ──────────────────────────────────────────────────────────────

  Future<void> _download() async {
    if (_downloading) return;

    // Derive the best extension we know.
    final ext = _resolvedMime.isNotEmpty
        ? _extensionFromMime(_resolvedMime)
        : _extensionFromUrl(widget.attachmentUrl);
    final filename = '${widget.title}${ext.isNotEmpty ? ext : ''}';

    if (kIsWeb) {
      // On web: open in browser — the browser will download it.
      // Also show snackbar with correct filename hint.
      await _openInBrowser();
      if (mounted && ext.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save the file as: $filename'),
            duration: const Duration(seconds: 6),
            backgroundColor: Colors.blue.shade700,
          ),
        );
      }
      return;
    }

    // On native: download bytes and save to temp file with correct extension.
    setState(() => _downloading = true);
    try {
      final response = await http
          .get(Uri.parse(widget.attachmentUrl))
          .timeout(const Duration(seconds: 60));

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        setState(() => _downloading = false);
        ShareHelper.shareDocument(
          context,
          url: widget.attachmentUrl,
          title: filename,
        );
      }
    } catch (e) {
      debugPrint('DocumentViewer: download failed: $e');
      if (mounted) {
        setState(() => _downloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  // ──────────────────────────────────────────────────────────────
  // UI builders
  // ──────────────────────────────────────────────────────────────

  Widget _buildFallbackView() {
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
            'This document format is not supported for preview.\n'
            'Tap the button below to open or download it.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _download,
            icon: const Icon(Icons.download),
            label: const Text('Download / Open'),
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
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackView(),
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
        errorWidget: (context, url, error) => _buildFallbackView(),
      ),
    );
  }

  Widget _buildOfficeDocViewer() {
    if (kIsWeb) {
      return platform_viewer.buildOfficeDocWebView(widget.attachmentUrl);
    }

    final encodedUrl = Uri.encodeComponent(widget.attachmentUrl);
    final viewerUrl =
        'https://docs.google.com/gview?embedded=true&url=$encodedUrl';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) =>
              debugPrint('Office doc viewer: page started loading'),
          onWebResourceError: (error) => debugPrint(
            'Office doc viewer error: ${error.description} (${error.errorCode})',
          ),
        ),
      )
      ..loadRequest(Uri.parse(viewerUrl));

    return WebViewWidget(controller: controller);
  }

  Widget _buildPdfViewer() {
    if (kIsWeb) {
      return platform_viewer.buildPdfWebView(widget.attachmentUrl);
    }

    return SfPdfViewer.network(
      widget.attachmentUrl,
      canShowScrollHead: false,
      canShowScrollStatus: false,
      onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
        debugPrint(
            'PDF Load Failed: ${details.error} - ${details.description}');
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

  // ──────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => ShareHelper.shareDocument(
              context,
              url: widget.attachmentUrl,
              title: widget.title,
            ),
            tooltip: 'Share',
          ),
          IconButton(
            icon: _downloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download),
            onPressed: _downloading ? null : _download,
            tooltip: 'Download',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: _detecting
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Detecting document type…'),
                  ],
                ),
              )
            : Center(
                child: switch (_docType) {
                  _DocType.pdf => _buildPdfViewer(),
                  _DocType.image => _buildImageViewer(),
                  _DocType.office => _buildOfficeDocViewer(),
                  _DocType.unknown => _buildFallbackView(),
                },
              ),
      ),
    );
  }
}
