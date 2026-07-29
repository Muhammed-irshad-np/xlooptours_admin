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

      // Extract filename from URL or derive a sensible default
      String filename = _extractFilename(url, title);

      final mimeType = _getMimeType(filename);

      XFile xFile;

      if (kIsWeb) {
        xFile = XFile.fromData(
          response.bodyBytes,
          name: filename,
          mimeType: mimeType,
        );
      } else {
        // For Native platforms, save to temporary file first for better share sheet support
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$filename');
        await tempFile.writeAsBytes(response.bodyBytes);

        xFile = XFile(tempFile.path, name: filename, mimeType: mimeType);
      }

      // We pass the Subject and Text to pre-fill the share action (like Email subject)
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

  /// Extracts a filename from a Firebase Storage URL.
  ///
  /// Firebase encodes the original filename in the URL path segment.
  /// This method URL-decodes the path and extracts the last segment that
  /// contains a file extension. Falls back to a title-based name.
  static String _extractFilename(String url, String title) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        // URL-decode the last path segment to get the original filename
        final lastSegment = Uri.decodeComponent(pathSegments.last);
        // Remove any query string residue
        final cleanSegment = lastSegment.split('?').first;
        if (cleanSegment.contains('.')) {
          return cleanSegment;
        }
      }
    } catch (_) {}

    // Fallback: derive from title with a generic extension
    // Sanitize the title for use as a filename
    final sanitized = title.replaceAll(RegExp(r'[^\w\s\-.]'), '').trim();
    return sanitized.isNotEmpty ? sanitized : 'document';
  }

  /// Returns the MIME type for a given filename based on its extension.
  ///
  /// Supports common document, image, and spreadsheet formats.
  static String? _getMimeType(String filename) {
    final lowerCaseName = filename.toLowerCase();

    // Images
    if (lowerCaseName.endsWith('.jpg') || lowerCaseName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerCaseName.endsWith('.png')) return 'image/png';
    if (lowerCaseName.endsWith('.gif')) return 'image/gif';
    if (lowerCaseName.endsWith('.webp')) return 'image/webp';
    if (lowerCaseName.endsWith('.bmp')) return 'image/bmp';

    // Documents
    if (lowerCaseName.endsWith('.pdf')) return 'application/pdf';
    if (lowerCaseName.endsWith('.doc')) return 'application/msword';
    if (lowerCaseName.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }

    // Spreadsheets
    if (lowerCaseName.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lowerCaseName.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lowerCaseName.endsWith('.csv')) return 'text/csv';

    // Presentations
    if (lowerCaseName.endsWith('.ppt')) {
      return 'application/vnd.ms-powerpoint';
    }
    if (lowerCaseName.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }

    // Text
    if (lowerCaseName.endsWith('.txt')) return 'text/plain';
    if (lowerCaseName.endsWith('.rtf')) return 'application/rtf';

    // Fallback — application/octet-stream is a safe generic binary type
    return 'application/octet-stream';
  }
}
