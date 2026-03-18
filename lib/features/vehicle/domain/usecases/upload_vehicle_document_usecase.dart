import 'package:image_picker/image_picker.dart';
import '../repositories/vehicle_repository.dart';

class UploadVehicleDocumentUseCase {
  final VehicleRepository repository;

  UploadVehicleDocumentUseCase(this.repository);

  Future<String> call(XFile file, String vehicleId, String docType) async {
    return await repository.uploadDocumentAttachment(file, vehicleId, docType);
  }
}
