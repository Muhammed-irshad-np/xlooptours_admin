import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ShareHelper {
  static Future<void> shareDocument(
    BuildContext context, {
    required String url,
    required String title,
    String? resolvedMime, // Optional: pass already-detected MIME to skip re-detection
  }) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing document to share...'),
          duration: Duration(seconds: 1),
        ),
      );

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download document. Status: ${response.statusCode}',
        );
      }

      final bytes = response.bodyBytes;

      // Detect MIME type: prefer caller-supplied, then magic bytes, then URL extension.
      final mime = resolvedMime?.isNotEmpty == true
          ? resolvedMime!
          : (_detectMimeFromBytes(bytes).isNotEmpty
              ? _detectMimeFromBytes(bytes)
              : _mimeFromUrl(url));

      final ext = _extensionFromMime(mime);

      // Build filename from title + correct extension.
      final sanitized = title.replaceAll(RegExp(r'[^\w\s\-.]'), '').trim();
      final baseName = sanitized.isNotEmpty ? sanitized : 'document';
      final filename = ext.isNotEmpty ? '$baseName$ext' : baseName;

      XFile xFile;

      if (kIsWeb) {
        xFile = XFile.fromData(
          bytes,
          name: filename,
          mimeType: mime.isNotEmpty ? mime : null,
        );
      } else {
        // For native platforms, save to temp file first for better share sheet support.
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$filename');
        await tempFile.writeAsBytes(bytes);
        xFile = XFile(tempFile.path, name: filename, mimeType: mime.isNotEmpty ? mime : null);
      }

      await Share.shareXFiles(
        [xFile],
        text: 'Sharing document: $title',
        subject: title,
      );
    } catch (e) {
      debugPrint('Share error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to prepare document for sharing.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Magic bytes detection
  // ──────────────────────────────────────────────────────────────

  static String _detectMimeFromBytes(List<int> b) {
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
    if (b.length >= 12 &&
        b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return 'image/webp'; // WebP
    }
    if (b.length >= 4 &&
        b[0] == 0x50 && b[1] == 0x4B && b[2] == 0x03 && b[3] == 0x04) {
      // ZIP-based Office (xlsx, docx, pptx) — default to xlsx
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (b.length >= 8 &&
        b[0] == 0xD0 && b[1] == 0xCF && b[2] == 0x11 && b[3] == 0xE0 &&
        b[4] == 0xA1 && b[5] == 0xB1 && b[6] == 0x1A && b[7] == 0xE1) {
      return 'application/vnd.ms-excel'; // OLE2 (.xls/.doc)
    }
    return '';
  }

  // ──────────────────────────────────────────────────────────────
  // Extension / MIME helpers
  // ──────────────────────────────────────────────────────────────

  static String _mimeFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final rawPath = uri.path;
      final oIndex = rawPath.indexOf('/o/');
      final objectEncoded = oIndex != -1 ? rawPath.substring(oIndex + 3) : rawPath;
      final objectDecoded = Uri.decodeComponent(objectEncoded);
      final filename = objectDecoded.split('/').last.split('?').first;
      final dotIndex = filename.lastIndexOf('.');
      if (dotIndex != -1 && dotIndex < filename.length - 1) {
        return _getMimeType(filename) ?? '';
      }
    } catch (_) {}
    return '';
  }

  static String _extensionFromMime(String mime) {
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

  /// Returns the MIME type for a given filename based on its extension.
  static String? _getMimeType(String filename) {
    final lowerCaseName = filename.toLowerCase();
    if (lowerCaseName.endsWith('.jpg') || lowerCaseName.endsWith('.jpeg')) return 'image/jpeg';
    if (lowerCaseName.endsWith('.png')) return 'image/png';
    if (lowerCaseName.endsWith('.gif')) return 'image/gif';
    if (lowerCaseName.endsWith('.webp')) return 'image/webp';
    if (lowerCaseName.endsWith('.bmp')) return 'image/bmp';
    if (lowerCaseName.endsWith('.pdf')) return 'application/pdf';
    if (lowerCaseName.endsWith('.doc')) return 'application/msword';
    if (lowerCaseName.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lowerCaseName.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lowerCaseName.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (lowerCaseName.endsWith('.csv')) return 'text/csv';
    if (lowerCaseName.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lowerCaseName.endsWith('.pptx')) return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    if (lowerCaseName.endsWith('.txt')) return 'text/plain';
    if (lowerCaseName.endsWith('.rtf')) return 'application/rtf';
    return 'application/octet-stream';
  }
}
