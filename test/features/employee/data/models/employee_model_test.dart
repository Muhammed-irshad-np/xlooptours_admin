import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/employee/data/models/employee_model.dart';

void main() {
  const employee = EmployeeModel(
    id: 'e1',
    fullName: 'Mohammed Ali',
    firstName: 'Mohammed',
    lastName: 'Ali',
    position: 'Driver',
    email: '',
    phoneNumber: '',
    nationality: '',
    idType: 'Iqama',
    idNumber: '',
    gender: 'Male',
  );

  test('round-trips first and last name through JSON', () {
    final json = employee.toJson();
    expect(json['firstName'], 'Mohammed');
    expect(json['lastName'], 'Ali');

    final restored = EmployeeModel.fromJson(json);
    expect(restored.fullName, 'Mohammed Ali');
    expect(restored.firstName, 'Mohammed');
    expect(restored.lastName, 'Ali');
  });

  test('reads employees saved before the name was split', () {
    final json = employee.toJson()
      ..remove('firstName')
      ..remove('lastName');

    final restored = EmployeeModel.fromJson(json);
    expect(restored.fullName, 'Mohammed Ali');
    expect(restored.firstName, isNull);
    expect(restored.lastName, isNull);
  });
}
