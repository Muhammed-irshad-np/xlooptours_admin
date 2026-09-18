import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/data/models/expense_model.dart';
import 'package:xloop_invoice/features/finance/domain/entities/expense_entity.dart';

/// `employeeId` carries two historical meanings, so these tests pin down which
/// reading applies to which shape of row. Getting this wrong silently
/// mis-attributes costs to whoever happened to file the claim.
ExpenseEntity _expense({
  String? employeeId,
  String? employeeName,
  String? submittedByEmployeeId,
  String? salaryPaymentId,
}) {
  return ExpenseEntity(
    id: 'e-1',
    referenceNumber: '#1001',
    date: DateTime(2025, 1, 1),
    createdAt: DateTime(2025, 1, 1),
    submittedBy: 'Coordinator',
    submittedByRole: 'ADMIN',
    expenseCategory: 'EMPLOYEES',
    expenseType: 'Iqama Renewal',
    amount: 650,
    currency: 'SAR',
    fundAccountId: 'acc-1',
    employeeId: employeeId,
    employeeName: employeeName,
    submittedByEmployeeId: submittedByEmployeeId,
    salaryPaymentId: salaryPaymentId,
  );
}

void main() {
  group('Expense employee attribution', () {
    test('legacy row treats employeeId as the submitter, not a beneficiary', () {
      // Written by the old form, where the "Submitted By" picker fed employeeId.
      final e = _expense(employeeId: 'emp-filer');

      expect(e.beneficiaryEmployeeId, isNull);
      expect(e.beneficiaryEmployeeName, isNull);
      expect(e.hasEmployeeAttribution, isFalse);
      expect(e.resolvedSubmittedByEmployeeId, equals('emp-filer'));
    });

    test('new row reads employeeId as the beneficiary', () {
      final e = _expense(
        employeeId: 'emp-target',
        employeeName: 'Ahmed Khan',
        submittedByEmployeeId: 'emp-filer',
      );

      expect(e.beneficiaryEmployeeId, equals('emp-target'));
      expect(e.beneficiaryEmployeeName, equals('Ahmed Khan'));
      expect(e.hasEmployeeAttribution, isTrue);
      expect(e.resolvedSubmittedByEmployeeId, equals('emp-filer'));
    });

    test('payroll mirror is a beneficiary row with no submitter record', () {
      // Salary mirrors have always stored the beneficiary in employeeId.
      final e = _expense(
        employeeId: 'emp-target',
        employeeName: 'Ahmed Khan',
        salaryPaymentId: 'pay-1',
      );

      expect(e.beneficiaryEmployeeId, equals('emp-target'));
      expect(e.hasEmployeeAttribution, isTrue);
      expect(e.resolvedSubmittedByEmployeeId, isNull);
    });

    test('a row logged from an alert is attributed without a submitter record', () {
      // The person updating the document may not have an employee record of
      // their own, so employeeName is the only marker such a row carries.
      final e = _expense(
        employeeId: 'emp-target',
        employeeName: 'Ahmed Khan',
      );

      expect(e.beneficiaryEmployeeId, equals('emp-target'));
      expect(e.beneficiaryEmployeeName, equals('Ahmed Khan'));
      expect(e.hasEmployeeAttribution, isTrue);
      expect(e.resolvedSubmittedByEmployeeId, isNull);
    });

    test('a new row with no beneficiary stays unattributed', () {
      final e = _expense(submittedByEmployeeId: 'emp-filer');

      expect(e.beneficiaryEmployeeId, isNull);
      expect(e.hasEmployeeAttribution, isFalse);
      expect(e.resolvedSubmittedByEmployeeId, equals('emp-filer'));
    });

    test('copyWith carries and clears submittedByEmployeeId', () {
      final e = _expense(submittedByEmployeeId: 'emp-filer');

      expect(
        e.copyWith(submittedByEmployeeId: 'emp-other').submittedByEmployeeId,
        equals('emp-other'),
      );
      expect(
        e.copyWith(clearSubmittedByEmployeeId: true).submittedByEmployeeId,
        isNull,
      );
    });
  });

  group('Expense model serialization', () {
    test('submittedByEmployeeId survives a toJson/fromJson round trip', () {
      final model = ExpenseModel.fromEntity(
        _expense(
          employeeId: 'emp-target',
          employeeName: 'Ahmed Khan',
          submittedByEmployeeId: 'emp-filer',
        ),
      );

      final restored = ExpenseModel.fromJson(model.toJson());

      expect(restored.submittedByEmployeeId, equals('emp-filer'));
      expect(restored.beneficiaryEmployeeId, equals('emp-target'));
      expect(restored.beneficiaryEmployeeName, equals('Ahmed Khan'));
    });

    test('a document written before the split decodes as a legacy row', () {
      final model = ExpenseModel.fromEntity(_expense(employeeId: 'emp-filer'));
      final json = model.toJson()..remove('submittedByEmployeeId');

      final restored = ExpenseModel.fromJson(json);

      expect(restored.submittedByEmployeeId, isNull);
      expect(restored.beneficiaryEmployeeId, isNull);
      expect(restored.resolvedSubmittedByEmployeeId, equals('emp-filer'));
    });
  });
}
