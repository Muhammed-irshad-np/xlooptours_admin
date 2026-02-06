import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  static final ImageService instance = ImageService._init();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  ImageService._init();

  Future<XFile?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Compress image to 70% quality
        maxWidth: 1920, // Resize if larger than Full HD
        maxHeight: 1920,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  Future<String?> uploadVehicleImage(
    XFile file,
    String vehicleId, {
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint('ImageService: Starting upload for vehicle $vehicleId');
      final extension = file.name.split('.').last.toLowerCase();
      final ref = _storage.ref().child(
        'vehicles/$vehicleId/${DateTime.now().millisecondsSinceEpoch}.$extension',
      );

      // Simple MIME type detection based on extension
      String contentType = 'image/jpeg';
      if (extension == 'png') contentType = 'image/png';

      final metadata = SettableMetadata(contentType: contentType);

      UploadTask task;
      if (kIsWeb) {
        final data = await file.readAsBytes();
        debugPrint('ImageService: Read ${data.length} bytes');
        task = ref.putData(data, metadata);
      } else {
        debugPrint('ImageService: Uploading file from path ${file.path}');
        task = ref.putFile(File(file.path), metadata);
      }

      task.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        debugPrint('ImageService: Progress $progress');
        if (onProgress != null) {
          onProgress(progress);
        }
      });

      await task.timeout(const Duration(minutes: 2));

      debugPrint('ImageService: Upload complete, getting URL...');
      final downloadUrl = await ref.getDownloadURL();
      debugPrint('ImageService: URL retrieved: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('ImageService: Error uploading image: $e');
      return null;
    }
  }
}
