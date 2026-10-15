import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/employee/data/models/employee_role_model.dart';
import 'package:xloop_invoice/features/employee/domain/entities/employee_role_entity.dart';

void main() {
  test('round-trips through json', () {
    const role = EmployeeRoleModel(
      id: 'r1',
      name: 'Accountant',
      category: EmployeeRoleCategory.office,
    );

    expect(EmployeeRoleModel.fromJson(role.toJson()), role);
  });

  test('unknown or missing category falls back to Other', () {
    expect(
      EmployeeRoleModel.fromJson({'id': 'r1', 'name': 'X'}).category,
      EmployeeRoleCategory.other,
    );
    expect(
      EmployeeRoleModel.fromJson({
        'id': 'r1',
        'name': 'X',
        'category': 'Bogus',
      }).category,
      EmployeeRoleCategory.other,
    );
  });

  test('defaults are the previously hardcoded positions and groups', () {
    final byName = {
      for (final r in EmployeeRoleEntity.defaults) r.name: r.category,
    };

    expect(byName.keys, [
      'CEO',
      'COO',
      'CFO',
      'Driver',
      'Senior Software Developer',
      'Administrative Officer',
      'Other',
    ]);
    expect(byName['CFO'], EmployeeRoleCategory.management);
    expect(byName['Administrative Officer'], EmployeeRoleCategory.office);
  });

  test('only the defaults are built-in', () {
    expect(EmployeeRoleEntity.defaults.every((r) => r.isBuiltIn), isTrue);
    expect(
      const EmployeeRoleEntity(id: 'r1', name: 'Accountant').isBuiltIn,
      isFalse,
    );
  });
}
