import 'package:image_picker/image_picker.dart';
import '../repositories/vehicle_repository.dart';

class UploadVehicleImageUseCase {
  final VehicleRepository repository;

  UploadVehicleImageUseCase(this.repository);

  Future<String> call(XFile image, String vehicleId) async {
    return await repository.uploadVehicleImage(image, vehicleId);
  }
}
