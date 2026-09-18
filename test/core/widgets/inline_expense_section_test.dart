import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xloop_invoice/core/widgets/inline_expense_section.dart';
import 'package:xloop_invoice/features/employee/domain/entities/employee_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/expense_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_policy_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_account_entity.dart';

/// The inline section is what turns an alert into money in the ledger, so the
/// rules it enforces and the row it produces are pinned down here.
const policy = FinancePolicyEntity(receiptRequiredAbove: 100);

final account = FundAccountEntity(
  id: 'acc-1',
  name: 'Main Cash',
  code: 'MC',
  type: FundAccountType.pettyCash,
  currency: 'BHD',
  createdAt: DateTime(2025, 1, 1),
);

final sara = EmployeeEntity(
  id: 'emp-sara',
  fullName: 'Sara Ali',
  position: 'Coordinator',
  email: 's@x.com',
  phoneNumber: '1',
  nationality: 'SA',
  idType: 'Iqama',
  idNumber: '1',
  gender: 'F',
);

InlineExpenseController _controller({
  String category = 'EMPLOYEES',
  String type = 'Iqama Renewal',
  TextEditingController? amountSource,
}) {
  return InlineExpenseController(
    category: category,
    defaultType: type,
    amountSource: amountSource,
  );
}

const employeeAttribution = ExpenseAttribution(
  label: 'Ahmed Khan',
  employeeId: 'emp-ahmed',
  employeeName: 'Ahmed Khan',
);

const vehicleAttribution = ExpenseAttribution(
  label: 'ABC-1234 · Toyota Hiace',
  vehicleId: 'veh-1',
  vehicleName: 'ABC-1234 - Hiace',
  mileageKm: 140250,
);

ExpenseEntity _draft(
  InlineExpenseController c, {
  ExpenseAttribution attribution = employeeAttribution,
}) {
  return c.buildDraft(
    attribution: attribution,
    description: 'Iqama renewal — Ahmed Khan',
    accounts: [account],
    employees: [sara],
    fallbackSubmitterName: 'Admin User',
    fallbackSubmitterRole: 'ADMIN',
    fallbackSubmitterUserId: 'uid-1',
  );
}

void main() {
  group('InlineExpenseController.validate', () {
    test('passes silently while the section is switched off', () {
      final c = _controller();
      // Deliberately incomplete — none of it matters until it is enabled.
      expect(c.validate(policy), isNull);
    });

    test('rejects a zero or unparseable amount', () {
      final c = _controller()
        ..enabled = true
        ..accountId = 'acc-1';

      expect(c.validate(policy), contains('amount'));

      c.ownAmount.text = 'abc';
      expect(c.validate(policy), contains('amount'));
    });

    test('rejects a missing fund account', () {
      final c = _controller()..enabled = true;
      c.ownAmount.text = '650';

      expect(c.validate(policy), contains('account'));
    });

    test('requires a receipt at or above the configured threshold', () {
      final c = _controller()
        ..enabled = true
        ..accountId = 'acc-1';

      c.ownAmount.text = '99.99';
      expect(c.validate(policy), isNull);

      c.ownAmount.text = '100';
      expect(c.validate(policy), contains('receipt'));

      c.receipt = XFile('/tmp/receipt.pdf');
      expect(c.validate(policy), isNull);
    });

    test('uses the configured threshold, not a hardcoded one', () {
      final c = _controller()
        ..enabled = true
        ..accountId = 'acc-1';
      c.ownAmount.text = '250';

      expect(
        c.validate(const FinancePolicyEntity(receiptRequiredAbove: 500)),
        isNull,
      );
      expect(
        c.validate(const FinancePolicyEntity(receiptRequiredAbove: 200)),
        contains('receipt'),
      );
    });
  });

  group('InlineExpenseController amount source', () {
    test('reads from the host dialog field when one is supplied', () {
      final hostCost = TextEditingController(text: '75.50');
      final c = _controller(amountSource: hostCost);

      expect(c.usesExternalAmount, isTrue);
      expect(c.amount, equals(75.50));

      // Its own field is ignored while a source is attached.
      c.ownAmount.text = '999';
      expect(c.amount, equals(75.50));
    });

    test('falls back to its own field when no source is supplied', () {
      final c = _controller();
      c.ownAmount.text = '42';

      expect(c.usesExternalAmount, isFalse);
      expect(c.amount, equals(42));
    });
  });

  group('InlineExpenseController.buildDraft', () {
    test('produces a pending row attributed to the employee', () {
      final c = _controller()
        ..enabled = true
        ..accountId = 'acc-1';
      c.ownAmount.text = '650';

      final e = _draft(c);

      expect(e.status, equals(ExpenseStatus.pending));
      expect(e.expenseCategory, equals('EMPLOYEES'));
      expect(e.expenseType, equals('Iqama Renewal'));
      expect(e.amount, equals(650));
      expect(e.fundAccountId, equals('acc-1'));
      expect(e.fundAccountName, equals('Main Cash'));
      expect(e.employeeId, equals('emp-ahmed'));
      expect(e.beneficiaryEmployeeId, equals('emp-ahmed'));
      expect(e.hasEmployeeAttribution, isTrue);
      expect(e.vehicleId, isNull);
    });

    test('produces a row attributed to a vehicle, with its odometer', () {
      final c = _controller(category: 'VEHICLES', type: 'Istimara Renewal')
        ..enabled = true
        ..accountId = 'acc-1';
      c.ownAmount.text = '300';

      final e = _draft(c, attribution: vehicleAttribution);

      expect(e.expenseCategory, equals('VEHICLES'));
      expect(e.vehicleId, equals('veh-1'));
      expect(e.vehicleName, equals('ABC-1234 - Hiace'));
      expect(e.mileageKm, equals(140250));
      // A vehicle cost is not carried for any one person.
      expect(e.employeeId, isNull);
      expect(e.hasEmployeeAttribution, isFalse);
    });

    test('produces a company row carrying no employee or vehicle', () {
      // A CR renewal is not spent on any one person or vehicle, so both
      // attribution ids stay empty and it is simply a COMPANY cost.
      final c = _controller(
        category: 'COMPANY',
        type: 'Commercial Registration (CR) Renewal',
      )..accountId = 'acc-1';
      c.ownAmount.text = '1200';

      final e = _draft(
        c,
        attribution: const ExpenseAttribution(
          label: 'Company · Commercial License',
        ),
      );

      expect(e.expenseCategory, equals('COMPANY'));
      expect(e.employeeId, isNull);
      expect(e.employeeName, isNull);
      expect(e.vehicleId, isNull);
      expect(e.mileageKm, isNull);
      expect(e.hasEmployeeAttribution, isFalse);
      expect(e.amount, equals(1200));
    });

    test('defaults the submitter to the signed-in user', () {
      final c = _controller()..accountId = 'acc-1';
      c.ownAmount.text = '650';

      final e = _draft(c);

      expect(e.submittedBy, equals('Admin User'));
      expect(e.submittedByRole, equals('ADMIN'));
      expect(e.submittedByUserId, equals('uid-1'));
      expect(e.submittedByEmployeeId, isNull);
    });

    test('an explicit submitter pick replaces the signed-in user', () {
      final c = _controller()
        ..accountId = 'acc-1'
        ..submitterEmployeeId = 'emp-sara';
      c.ownAmount.text = '650';

      final e = _draft(c);

      expect(e.submittedBy, equals('Sara Ali'));
      expect(e.submittedByRole, equals('COORDINATOR'));
      expect(e.submittedByEmployeeId, equals('emp-sara'));
      // The uid belongs to whoever is signed in, so it must not ride along.
      expect(e.submittedByUserId, isNull);
    });

    test('picking the account adopts its currency', () {
      final c = _controller();
      expect(c.currency, equals('SAR'));

      // Mirrors what the dropdown's onChanged does.
      c.accountId = account.id;
      c.currency = account.currency;

      expect(_draft(c).currency, equals('BHD'));
    });

    test('blank notes are stored as null rather than an empty string', () {
      final c = _controller()..accountId = 'acc-1';
      c.ownAmount.text = '650';

      c.notes.text = '   ';
      expect(_draft(c).notes, isNull);

      c.notes.text = '  paid at the office  ';
      expect(_draft(c).notes, equals('paid at the office'));
    });

    test('the date defaults to today and honours a backdate', () {
      final c = _controller()..accountId = 'acc-1';
      c.ownAmount.text = '650';

      final today = DateTime.now();
      expect(_draft(c).date.day, equals(today.day));

      c.date = DateTime(2026, 3, 11);
      expect(_draft(c).date, equals(DateTime(2026, 3, 11)));
    });
  });
}
