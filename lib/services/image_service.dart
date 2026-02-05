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
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      return image;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  Future<String?> uploadVehicleImage(XFile file, String vehicleId) async {
    try {
      final ref = _storage.ref().child(
        'vehicles/$vehicleId/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (kIsWeb) {
        await ref.putData(await file.readAsBytes());
      } else {
        await ref.putFile(File(file.path));
      }

      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }
}
