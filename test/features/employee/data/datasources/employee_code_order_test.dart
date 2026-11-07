import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/employee/data/datasources/employee_remote_data_source.dart';

void main() {
  Map<String, dynamic> emp(String name, String position, [String? joinDate]) =>
      {'fullName': name, 'position': position, 'joinDate': joinDate};

  List<String> order(List<Map<String, dynamic>> employees) =>
      (List.of(employees)..sort(EmployeeRemoteDataSourceImpl.compareForCodes))
          .map((e) => e['fullName'] as String)
          .toList();

  test('CEO, COO and CFO come first, even without a join date', () {
    expect(
      order([
        emp('Driver A', 'Driver', '2019-01-01T00:00:00.000'),
        emp('Finance', 'CFO'),
        emp('Ops', 'COO'),
        emp('Boss', 'CEO'),
      ]),
      ['Boss', 'Ops', 'Finance', 'Driver A'],
    );
  });

  test('everyone else goes by join date, with no date last', () {
    expect(
      order([
        emp('No Date', 'Driver'),
        emp('Newer', 'Driver', '2023-05-01T00:00:00.000'),
        emp('Older', 'Administrative Officer', '2020-02-01T00:00:00.000'),
      ]),
      ['Older', 'Newer', 'No Date'],
    );
  });

  test('name breaks ties', () {
    expect(
      order([emp('bilal', 'Driver'), emp('Ahmed', 'Driver')]),
      ['Ahmed', 'bilal'],
    );
  });
}
