import 'package:image_picker/image_picker.dart';

import '../entities/odometer_reading_entity.dart';

abstract class OdometerRepository {
  Future<List<OdometerReadingEntity>> getReadings(String vehicleId);
  Future<List<OdometerReadingEntity>> getQuarantinedReadings();
  Future<List<OdometerReadingEntity>> getRecentReadings({int limit});
  Future<void> insertReading(OdometerReadingEntity reading);
  Future<void> updateReadingReview(OdometerReadingEntity reading);
  Future<String> uploadOdometerPhoto(
    XFile photo,
    String vehicleId,
    String readingId,
  );
}
