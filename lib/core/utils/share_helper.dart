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

      if (kIsWeb) {
        // On Web, file sharing support is limited and often triggers a download.
        // To allow sharing to WhatsApp/others, we share the link as text.
        await Share.share(
          '$title\n$url',
          subject: title,
        );
        return;
      }

      // For Native platforms, save to temporary file first for better share sheet support
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(response.bodyBytes);

      final xFile = XFile(
        tempFile.path,
        name: filename,
        mimeType: mimeType,
      );

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

  static String? _getMimeType(String filename) {
    final lowerCaseName = filename.toLowerCase();
    if (lowerCaseName.endsWith('.pdf')) return 'application/pdf';
    if (lowerCaseName.endsWith('.jpg') || lowerCaseName.endsWith('.jpeg'))
      return 'image/jpeg';
    if (lowerCaseName.endsWith('.png')) return 'image/png';
    return null;
  }
}
