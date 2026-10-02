import 'package:image_picker/image_picker.dart';

import '../../domain/entities/odometer_reading_entity.dart';
import '../../domain/repositories/odometer_repository.dart';
import '../datasources/odometer_remote_data_source.dart';
import '../models/odometer_reading_model.dart';

class OdometerRepositoryImpl implements OdometerRepository {
  final OdometerRemoteDataSource remoteDataSource;

  OdometerRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<OdometerReadingEntity>> getReadings(String vehicleId) =>
      remoteDataSource.getReadings(vehicleId);

  @override
  Future<List<OdometerReadingEntity>> getQuarantinedReadings() =>
      remoteDataSource.getQuarantinedReadings();

  @override
  Future<List<OdometerReadingEntity>> getRecentReadings({int limit = 500}) =>
      remoteDataSource.getRecentReadings(limit: limit);

  @override
  Future<void> insertReading(OdometerReadingEntity reading) =>
      remoteDataSource.insertReading(OdometerReadingModel.fromEntity(reading));

  @override
  Future<void> updateReadingReview(OdometerReadingEntity reading) =>
      remoteDataSource.updateReadingReview(
        OdometerReadingModel.fromEntity(reading),
      );

  @override
  Future<String> uploadOdometerPhoto(
    XFile photo,
    String vehicleId,
    String readingId,
  ) => remoteDataSource.uploadOdometerPhoto(photo, vehicleId, readingId);
}
