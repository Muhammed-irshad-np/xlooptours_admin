import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/vehicle/data/models/vehicle_model.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_documents.dart';

void main() {
  group('VehicleModel', () {
    final tDate = DateTime(2025, 12, 31);
    final mDate = DateTime(2024, 1, 1);

    final tVehicleModel = VehicleModel(
      id: '1',
      make: 'Toyota',
      model: 'Camry',
      year: 2022,
      color: 'Silver',
      plateNumber: 'ABC-123',
      type: 'Sedan',
      insurance: VehicleDocument(
        expiryDate: tDate,
        attachmentUrl: 'http://example.com/insurance.pdf',
        notificationDays: 30,
      ),
      registration: VehicleDocument(
        expiryDate: tDate,
        attachmentUrl: 'http://example.com/reg.pdf',
        notificationDays: 15,
      ),
      fahas: VehicleDocument(
        expiryDate: tDate,
        attachmentUrl: 'http://example.com/fahas.pdf',
        notificationDays: 7,
      ),
      maintenance: VehicleMaintenance(
        engineOil: MaintenanceRecord(
          date: mDate,
          mileage: 5000,
          attachmentUrl: 'http://example.com/oil.pdf',
          notificationDays: 10,
        ),
        gearOil: MaintenanceRecord(
          date: mDate,
          mileage: 40000,
        ),
      ),
    );

    final tJson = {
      'id': '1',
      'make': 'Toyota',
      'model': 'Camry',
      'year': 2022,
      'color': 'Silver',
      'plateNumber': 'ABC-123',
      'type': 'Sedan',
      'assignedDriverId': null,
      'imageUrl': null,
      'isActive': true,
      'insurance': {
        'expiryDate': tDate.toIso8601String(),
        'attachmentUrl': 'http://example.com/insurance.pdf',
        'notificationDays': 30,
      },
      'registration': {
        'expiryDate': tDate.toIso8601String(),
        'attachmentUrl': 'http://example.com/reg.pdf',
        'notificationDays': 15,
      },
      'fahas': {
        'expiryDate': tDate.toIso8601String(),
        'attachmentUrl': 'http://example.com/fahas.pdf',
        'notificationDays': 7,
      },
      'maintenance': {
        'engineOil': {
          'date': mDate.toIso8601String(),
          'mileage': 5000,
          'attachmentUrl': 'http://example.com/oil.pdf',
          'notificationDays': 10,
        },
        'gearOil': {
          'date': mDate.toIso8601String(),
          'mileage': 40000,
          'attachmentUrl': null,
          'notificationDays': null,
        },
        'housingOil': null,
        'tyreChange': null,
        'batteryChange': null,
      },
    };

    test('should return a valid model from JSON', () {
      // act
      final result = VehicleModel.fromJson(tJson);
      // assert
      expect(result.id, tVehicleModel.id);
      expect(result.insurance?.expiryDate, tVehicleModel.insurance?.expiryDate);
      expect(result.maintenance?.engineOil?.mileage, tVehicleModel.maintenance?.engineOil?.mileage);
    });

    test('should return a JSON map containing proper data', () {
      // act
      final result = tVehicleModel.toJson();
      // assert
      expect(result, tJson);
    });
  });
}
