import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// File types accepted as an expense receipt.
const receiptExtensions = ['jpg', 'jpeg', 'png', 'webp', 'pdf'];

/// Lets the user pick a receipt image or PDF. Returns null when cancelled.
///
/// Web has no file paths, so there the bytes are loaded up front and wrapped
/// in an in-memory [XFile]; elsewhere the file is read from disk on upload.
Future<XFile?> pickReceiptFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: receiptExtensions,
    withData: kIsWeb,
  );
  final file = result?.files.firstOrNull;
  if (file == null) return null;

  if (kIsWeb) {
    final bytes = file.bytes;
    return bytes == null ? null : XFile.fromData(bytes, name: file.name);
  }
  final path = file.path;
  return path == null ? null : XFile(path, name: file.name);
}

/// Whether a stored receipt URL points at a PDF rather than an image.
/// Storage URLs keep the object name (with its extension) before the query.
bool isPdfReceiptUrl(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  return path.toLowerCase().endsWith('.pdf');
}
