import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class ImageCompressionHelper {
  /// Compresses an image picked by ImagePicker using its built-in quality settings.
  /// This is highly recommended because it uses native APIs (Android/iOS) or Canvas (Web)
  /// which are extremely fast and memory-efficient.
  static Future<XFile?> pickAndCompressImage({
    required ImageSource source,
    int maxWidth = 1080,
    int maxHeight = 1080,
    int quality = 70,
  }) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
      );
      return image;
    } catch (e) {
      print('Error picking and compressing image: $e');
      return null;
    }
  }

  /// Manually compresses raw image bytes.
  /// This uses the pure Dart `image` package. It works on all platforms but can be
  /// CPU intensive for very large original images. Use [pickAndCompressImage] where possible.
  static Future<Uint8List?> compressBytes(
    Uint8List bytes, {
    int maxWidth = 1080,
    int quality = 70,
  }) async {
    try {
      // Decode the image
      final img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return null;

      // Resize if needed
      img.Image resizedImage = originalImage;
      if (originalImage.width > maxWidth) {
        resizedImage = img.copyResize(originalImage, width: maxWidth);
      }

      // Encode back to JPEG with specified quality
      final List<int> compressedData = img.encodeJpg(resizedImage, quality: quality);
      return Uint8List.fromList(compressedData);
    } catch (e) {
      print('Error compressing image bytes: $e');
      return null;
    }
  }
}
