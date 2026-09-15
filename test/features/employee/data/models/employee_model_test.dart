import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/employee/data/models/employee_model.dart';
import 'package:xloop_invoice/features/employee/domain/entities/employee_entity.dart';
import 'package:xloop_invoice/features/employee/domain/entities/external_vehicle_info.dart';

void main() {
  Map<String, dynamic> baseJson() => {
        'id': 'e1',
        'fullName': 'Wahid',
        'position': 'Driver',
        'gender': 'Male',
      };

  group('employmentType migration', () {
    test('legacy driverType is carried over when employmentType is absent', () {
      final model = EmployeeModel.fromJson(
        baseJson()..['driverType'] = 'External',
      );

      expect(model.employmentType, EmploymentType.external);
      expect(model.isExternal, isTrue);
    });

    test('records with neither field default to Internal', () {
      final model = EmployeeModel.fromJson(baseJson());

      expect(model.employmentType, EmploymentType.internal);
      expect(model.isExternal, isFalse);
    });

    test('employmentType wins over a stale driverType', () {
      final model = EmployeeModel.fromJson(
        baseJson()
          ..['employmentType'] = 'Internal'
          ..['driverType'] = 'External',
      );

      expect(model.employmentType, EmploymentType.internal);
    });
  });

  group('toJson', () {
    test('mirrors employmentType into legacy driverType for drivers', () {
      final json = EmployeeModel.fromJson(
        baseJson()..['employmentType'] = 'External',
      ).toJson();

      expect(json['employmentType'], 'External');
      expect(json['driverType'], 'External');
    });

    test('leaves legacy driverType null for non-drivers', () {
      final json = EmployeeModel.fromJson(
        baseJson()
          ..['position'] = 'Administrative Officer'
          ..['employmentType'] = 'External',
      ).toJson();

      expect(json['employmentType'], 'External');
      expect(json['driverType'], isNull);
    });
  });

  group('external vehicle', () {
    test('round-trips through JSON', () {
      final original = EmployeeModel.fromJson(baseJson()).copyWith(
        employmentType: EmploymentType.external,
        externalVehicle: const ExternalVehicleInfo(
          make: 'GMC',
          model: 'Yukon',
          year: 2018,
          vehicleColor: 'Gold',
          plateNumber: '3360 GLJ',
        ),
      );

      final restored = EmployeeModel.fromJson(original.toJson());

      // Field-wise: Equatable also compares runtimeType, so the rehydrated
      // ExternalVehicleInfoModel never equals the plain entity it came from.
      expect(restored.externalVehicle!.make, 'GMC');
      expect(restored.externalVehicle!.model, 'Yukon');
      expect(restored.externalVehicle!.year, 2018);
      expect(restored.externalVehicle!.vehicleColor, 'Gold');
      expect(restored.externalVehicle!.plateNumber, '3360 GLJ');
      expect(restored.isExternalDriver, isTrue);
      expect(
        restored.externalVehicle!.summary,
        'GMC Yukon 2018 · Gold · 3360 GLJ',
      );
    });

    test('is absent for internal staff', () {
      final model = EmployeeModel.fromJson(baseJson());

      expect(model.externalVehicle, isNull);
      expect(model.isExternalDriver, isFalse);
    });
  });

  group('isDriver', () {
    test('matches any driver position label', () {
      for (final position in ['Driver', 'External Driver', 'Senior driver']) {
        final model = EmployeeModel.fromJson(baseJson()..['position'] = position);
        expect(model.isDriver, isTrue, reason: position);
      }
    });

    test('is false for non-driving positions', () {
      final model = EmployeeModel.fromJson(baseJson()..['position'] = 'CFO');
      expect(model.isDriver, isFalse);
    });
  });
}
