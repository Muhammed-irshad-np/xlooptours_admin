import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xloop_invoice/core/utils/image_compression_helper.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/entities/evaluation_entity.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/usecases/get_evaluation_by_id_usecase.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/usecases/submit_driver_form_usecase.dart';

class UploadState {
  final bool isUploading;
  final String? url;
  final String? error;
  final DateTime? timestamp;

  UploadState({this.isUploading = false, this.url, this.error, this.timestamp});
}

class DriverFormProvider extends ChangeNotifier {
  final GetEvaluationByIdUseCase getEvaluationByIdUseCase;
  final SubmitDriverFormUseCase submitDriverFormUseCase;

  DriverFormProvider({
    required this.getEvaluationByIdUseCase,
    required this.submitDriverFormUseCase,
  });

  EvaluationEntity? _evaluation;
  EvaluationEntity? get evaluation => _evaluation;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Media tracking: key is the field name (e.g. 'full_body', 'vehicle_front')
  final Map<String, UploadState> _mediaUploads = {};
  Map<String, UploadState> get mediaUploads => _mediaUploads;

  Future<void> loadEvaluation(String id) async {
    _setLoading(true);
    final result = await getEvaluationByIdUseCase(id);
    _setLoading(false);

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
      },
      (entity) {
        _evaluation = entity;
        _errorMessage = null;
        // Pre-populate media uploads if any already exist on the server
        if (entity.media.isNotEmpty) {
          entity.media.forEach((key, data) {
            _mediaUploads[key] = UploadState(
              isUploading: false,
              url: data['url'] as String?,
              timestamp: data['timestamp'] != null 
                  ? DateTime.tryParse(data['timestamp'] as String) 
                  : null,
            );
          });
        }
        notifyListeners();
      },
    );
  }

  Future<void> captureAndUploadImage(String fieldKey) async {
    if (_evaluation == null) return;

    try {
      final XFile? image = await ImageCompressionHelper.pickAndCompressImage(
        source: ImageSource.camera,
        maxWidth: 1080,
        quality: 70,
      );

      if (image == null) return; // User cancelled

      _mediaUploads[fieldKey] = UploadState(isUploading: true);
      notifyListeners();

      final bytes = await image.readAsBytes();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('evaluations')
          .child('${_evaluation!.id}_$fieldKey.jpg');

      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();

      _mediaUploads[fieldKey] = UploadState(
        isUploading: false,
        url: url,
        timestamp: DateTime.now(),
      );
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _mediaUploads[fieldKey] = UploadState(
        isUploading: false,
        error: e.toString(),
      );
      notifyListeners();
    }
  }

  Future<bool> submitForm() async {
    if (_evaluation == null) return false;

    // Build the media map
    final Map<String, dynamic> mediaData = {};
    _mediaUploads.forEach((key, state) {
      if (state.url != null) {
        mediaData[key] = {
          'url': state.url,
          'timestamp': state.timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
        };
      }
    });

    // Enforce that all required photos are uploaded
    final requiredKeys = [
      'full_body',
      'shoes',
      'vehicle_front',
      'vehicle_back',
      'vehicle_left',
      'vehicle_right',
      'cabin_front',
      'cabin_rear',
    ];

    for (final key in requiredKeys) {
      if (!mediaData.containsKey(key)) {
        _errorMessage = 'Please upload all required photos.';
        notifyListeners();
        return false;
      }
    }

    _setLoading(true);
    final result = await submitDriverFormUseCase(_evaluation!.id, mediaData);
    _setLoading(false);

    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) {
        _errorMessage = null;
        loadEvaluation(_evaluation!.id);
        return true;
      },
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}