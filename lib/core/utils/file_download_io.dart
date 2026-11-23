import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [bytes] to a temp file and opens the share sheet so the user can
/// save or send it.
Future<void> saveFileBytes({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, name: fileName, mimeType: mimeType)],
    subject: fileName,
  );
}
