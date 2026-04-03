import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

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

      // Extract filename from URL or use a default one
      String filename = 'document.pdf';
      try {
        final uri = Uri.parse(url);
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          final lastSegment = pathSegments.last.split('?').first;
          if (lastSegment.contains('.')) {
            filename = Uri.decodeComponent(lastSegment);
          }
        }
      } catch (_) {}

      final mimeType = _getMimeType(filename);

      final xFile = XFile.fromData(
        response.bodyBytes,
        name: filename,
        mimeType: mimeType,
      );

      // We pass the Subject and Text to pre-fill the share action (like Email subject)
      await Share.shareXFiles([xFile], text: 'Sharing: $title', subject: title);
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

  static String? _getMimeType(String filename) {
    final lowerCaseName = filename.toLowerCase();
    if (lowerCaseName.endsWith('.pdf')) return 'application/pdf';
    if (lowerCaseName.endsWith('.jpg') || lowerCaseName.endsWith('.jpeg'))
      return 'image/jpeg';
    if (lowerCaseName.endsWith('.png')) return 'image/png';
    return null;
  }
}
