import 'dart:typed_data';

/// Holds the resolved upload information for a file.
class FileUploadInfo {
  /// The correct file extension including the leading dot (e.g. `.pdf`).
  final String extension;

  /// The correct MIME content-type (e.g. `application/pdf`).
  final String mimeType;

  const FileUploadInfo({required this.extension, required this.mimeType});
}

/// Utility class that determines the true file type of an uploaded file.
///
/// Resolution order:
/// 1. **Magic bytes** – Inspect the first few bytes of the file content to
///    identify well-known binary signatures (PDF, JPEG, PNG, GIF, WebP).
/// 2. **Extension fallback** – If magic bytes don't match, fall back to the
///    file-name extension reported by the OS/picker.
/// 3. **Generic fallback** – If neither resolves, use `application/octet-stream`.
///
/// This prevents the common problem where a file like `insurance` (no extension)
/// or `document.pdf` (correct name but stored without extension on storage)
/// gets saved with the wrong MIME type, causing it to open as garbled text
/// instead of in a PDF viewer.
class FileUploadHelper {
  FileUploadHelper._();

  /// Resolves the correct [FileUploadInfo] (extension + MIME type) for a file.
  ///
  /// [bytes] – the raw bytes of the file.
  /// [originalName] – the original file name as reported by the file picker
  ///   (used as a fallback if magic bytes don't match).
  static FileUploadInfo getUploadInfo(Uint8List bytes, String originalName) {
    // --- 1. Magic bytes detection ---
    if (_isPdf(bytes)) {
      return const FileUploadInfo(extension: '.pdf', mimeType: 'application/pdf');
    }
    if (_isJpeg(bytes)) {
      return const FileUploadInfo(extension: '.jpg', mimeType: 'image/jpeg');
    }
    if (_isPng(bytes)) {
      return const FileUploadInfo(extension: '.png', mimeType: 'image/png');
    }
    if (_isGif(bytes)) {
      return const FileUploadInfo(extension: '.gif', mimeType: 'image/gif');
    }
    if (_isWebp(bytes)) {
      return const FileUploadInfo(extension: '.webp', mimeType: 'image/webp');
    }
    if (_isZip(bytes)) {
      // Office Open XML formats (docx, xlsx, pptx) are ZIP-based.
      // Try to guess from the file-name extension.
      final ext = _extensionFrom(originalName).toLowerCase();
      if (ext == '.docx') {
        return const FileUploadInfo(
          extension: '.docx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      }
      if (ext == '.xlsx') {
        return const FileUploadInfo(
          extension: '.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      }
      if (ext == '.pptx') {
        return const FileUploadInfo(
          extension: '.pptx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        );
      }
    }

    // --- 2. Extension-based fallback ---
    final ext = _extensionFrom(originalName).toLowerCase();
    switch (ext) {
      case '.pdf':
        return const FileUploadInfo(extension: '.pdf', mimeType: 'application/pdf');
      case '.jpg':
      case '.jpeg':
        return const FileUploadInfo(extension: '.jpg', mimeType: 'image/jpeg');
      case '.png':
        return const FileUploadInfo(extension: '.png', mimeType: 'image/png');
      case '.gif':
        return const FileUploadInfo(extension: '.gif', mimeType: 'image/gif');
      case '.webp':
        return const FileUploadInfo(extension: '.webp', mimeType: 'image/webp');
      case '.doc':
        return const FileUploadInfo(extension: '.doc', mimeType: 'application/msword');
      case '.docx':
        return const FileUploadInfo(
          extension: '.docx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        );
      case '.xls':
        return const FileUploadInfo(
          extension: '.xls',
          mimeType: 'application/vnd.ms-excel',
        );
      case '.xlsx':
        return const FileUploadInfo(
          extension: '.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      case '.ppt':
        return const FileUploadInfo(
          extension: '.ppt',
          mimeType: 'application/vnd.ms-powerpoint',
        );
      case '.pptx':
        return const FileUploadInfo(
          extension: '.pptx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        );
      case '.csv':
        return const FileUploadInfo(extension: '.csv', mimeType: 'text/csv');
      case '.txt':
        return const FileUploadInfo(extension: '.txt', mimeType: 'text/plain');
      default:
        // --- 3. Generic fallback ---
        final resolvedExt = ext.isNotEmpty ? ext : '.bin';
        return FileUploadInfo(
          extension: resolvedExt,
          mimeType: 'application/octet-stream',
        );
    }
  }

  /// Extracts the extension from a file name (e.g. `report.pdf` → `.pdf`).
  /// Returns an empty string if no extension is found.
  static String _extensionFrom(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1 || lastDot == fileName.length - 1) return '';
    return fileName.substring(lastDot);
  }

  // ─── Magic byte helpers ────────────────────────────────────────────────────

  /// PDF: starts with `%PDF`
  static bool _isPdf(Uint8List b) =>
      b.length >= 4 &&
      b[0] == 0x25 && // %
      b[1] == 0x50 && // P
      b[2] == 0x44 && // D
      b[3] == 0x46;   // F

  /// JPEG: starts with `FF D8 FF`
  static bool _isJpeg(Uint8List b) =>
      b.length >= 3 &&
      b[0] == 0xFF &&
      b[1] == 0xD8 &&
      b[2] == 0xFF;

  /// PNG: starts with `89 50 4E 47 0D 0A 1A 0A`
  static bool _isPng(Uint8List b) =>
      b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 && // P
      b[2] == 0x4E && // N
      b[3] == 0x47 && // G
      b[4] == 0x0D &&
      b[5] == 0x0A &&
      b[6] == 0x1A &&
      b[7] == 0x0A;

  /// GIF: starts with `GIF87a` or `GIF89a`
  static bool _isGif(Uint8List b) =>
      b.length >= 6 &&
      b[0] == 0x47 && // G
      b[1] == 0x49 && // I
      b[2] == 0x46 && // F
      b[3] == 0x38 && // 8
      (b[4] == 0x37 || b[4] == 0x39) && // 7 or 9
      b[5] == 0x61;   // a

  /// WebP: starts with `RIFF????WEBP`
  static bool _isWebp(Uint8List b) =>
      b.length >= 12 &&
      b[0] == 0x52 && // R
      b[1] == 0x49 && // I
      b[2] == 0x46 && // F
      b[3] == 0x46 && // F
      b[8] == 0x57 && // W
      b[9] == 0x45 && // E
      b[10] == 0x42 && // B
      b[11] == 0x50;   // P

  /// ZIP (also covers docx/xlsx/pptx): starts with `PK\x03\x04`
  static bool _isZip(Uint8List b) =>
      b.length >= 4 &&
      b[0] == 0x50 && // P
      b[1] == 0x4B && // K
      b[2] == 0x03 &&
      b[3] == 0x04;
}
