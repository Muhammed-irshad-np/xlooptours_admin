import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/employee/domain/entities/employee_entity.dart';

void main() {
  EmployeeEntity makeEmployee({
    required String id,
    required String name,
    required String position,
    String employmentType = EmploymentType.internal,
    bool isActive = true,
  }) {
    return EmployeeEntity(
      id: id,
      fullName: name,
      position: position,
      email: '$id@example.com',
      phoneNumber: '1234567890',
      nationality: 'Saudi',
      idType: 'Iqama',
      idNumber: '1234567890',
      gender: 'Male',
      employmentType: employmentType,
      isActive: isActive,
    );
  }

  final employees = [
    makeEmployee(id: '1', name: 'Internal Driver 1', position: 'Driver', employmentType: EmploymentType.internal),
    makeEmployee(id: '2', name: 'Internal Driver 2', position: 'Heavy Driver', employmentType: EmploymentType.internal),
    makeEmployee(id: '3', name: 'External Driver 1', position: 'Driver', employmentType: EmploymentType.external),
    makeEmployee(id: '4', name: 'External Driver 2', position: 'Freelance Driver', employmentType: EmploymentType.external),
    makeEmployee(id: '5', name: 'Manager 1', position: 'General Manager', employmentType: EmploymentType.internal),
    makeEmployee(id: '6', name: 'External Staff', position: 'Cleaner', employmentType: EmploymentType.external),
  ];

  group('Driver sub-tab filtering logic', () {
    test('All drivers tab includes all internal and external drivers', () {
      final allDrivers = employees.where((e) => e.isDriver).toList();
      expect(allDrivers.length, 4);
      expect(allDrivers.map((e) => e.id), containsAll(['1', '2', '3', '4']));
      expect(allDrivers.any((e) => e.id == '5'), isFalse);
      expect(allDrivers.any((e) => e.id == '6'), isFalse);
    });

    test('Internal drivers tab includes only internal drivers', () {
      final internalDrivers = employees.where((e) => e.isDriver && e.isInternal).toList();
      expect(internalDrivers.length, 2);
      expect(internalDrivers.map((e) => e.id), containsAll(['1', '2']));
      expect(internalDrivers.any((e) => e.isExternal), isFalse);
    });

    test('External drivers tab includes only external drivers', () {
      final externalDrivers = employees.where((e) => e.isDriver && e.isExternal).toList();
      expect(externalDrivers.length, 2);
      expect(externalDrivers.map((e) => e.id), containsAll(['3', '4']));
      expect(externalDrivers.any((e) => e.isInternal), isFalse);
      expect(externalDrivers.any((e) => e.id == '6'), isFalse); // Non-driver external staff excluded
    });
  });
}
