import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/data/models/fund_account_model.dart';

void main() {
  Map<String, dynamic> baseJson() => {
        'id': 'acc-1',
        'name': 'Treasury',
        'code': 'TR001',
        'type': 'other',
        'accountTypeId': 'treasury',
        'accountTypeName': 'Treasury',
        'currentBalanceMinor': 10000,
        'currency': 'SAR',
        'isActive': true,
        'createdAt': '2026-11-19T10:00:00.000',
      };

  test('people and roles assigned to an account survive a round trip', () {
    final account = FundAccountModel.fromJson({
      ...baseJson(),
      'assignedTo': 'Nithin',
      'assignedEmployeeIds': ['emp_nithin', ''],
      'assignedEmployeeNames': ['Nithin', 'Muhammed Saleh'],
      'assignedRoles': ['finance'],
    });

    // The empty id stays so ids and names keep lining up.
    expect(account.assignedEmployeeIds, ['emp_nithin', '']);
    expect(account.assignedEmployeeNames, ['Nithin', 'Muhammed Saleh']);
    expect(account.assignedRoles, ['finance']);

    final again = FundAccountModel.fromJson(account.toJson());
    expect(again.assignedEmployeeIds, account.assignedEmployeeIds);
    expect(again.assignedEmployeeNames, account.assignedEmployeeNames);
    expect(again.assignedRoles, account.assignedRoles);
    expect(again.assignedTo, 'Nithin');
  });

  test('an account saved before multiple assignees keeps its coordinator', () {
    final account = FundAccountModel.fromJson({
      ...baseJson(),
      'assignedTo': 'Driver Sami',
    });

    expect(account.assignedEmployeeIds, isEmpty);
    expect(account.assignedEmployeeNames, isEmpty);
    expect(account.assignedRoles, isEmpty);
    expect(account.assigneeNames, ['Driver Sami']);
    expect(account.hasAssignees, isTrue);
  });

  test('an unassigned account has no assignees', () {
    final account = FundAccountModel.fromJson(baseJson());
    expect(account.hasAssignees, isFalse);
    expect(account.assigneeLabel, isEmpty);
  });
}
