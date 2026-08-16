import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/domain/entities/expense_entity.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/void_expense_usecase.dart';

import 'test_finance_repository.dart';

void main() {
  late FakeFinanceRepository repo;
  late VoidExpenseUseCase useCase;

  setUp(() {
    repo = FakeFinanceRepository();
    useCase = VoidExpenseUseCase(repo);
  });

  ExpenseEntity paidExpense({String id = 'exp-001'}) => ExpenseEntity(
        id: id,
        referenceNumber: '#10001',
        date: DateTime(2025, 1, 15),
        createdAt: DateTime(2025, 1, 15),
        submittedBy: 'Driver A',
        submittedByRole: 'driver',
        expenseCategory: 'Fuel',
        expenseType: 'Regular Fuel',
        paymentMethod: 'cash',
        amount: 300,
        currency: 'SAR',
        fundAccountId: 'acc-001',
        status: ExpenseStatus.paid,
        ledgerEntryId: 'tx-001',
        paidBy: 'Manager A',
        paidAt: DateTime(2025, 1, 15),
      );

  group('VoidExpenseUseCase', () {
    test('returns voided expense with reverseLedgerEntryId', () async {
      final paid = paidExpense();
      repo.voidResult = paid.copyWith(
        status: ExpenseStatus.voided,
        voidedBy: 'Finance A',
        voidedAt: DateTime(2025, 1, 16),
        voidReason: 'Duplicate entry',
        reverseLedgerEntryId: 'tx-002',
      );

      final result = await useCase(
        expenseId: paid.id,
        actorName: 'Finance A',
        actorUserId: 'fin-001',
        reason: 'Duplicate entry',
      );

      expect(result.status, ExpenseStatus.voided);
      expect(result.reverseLedgerEntryId, 'tx-002');
      expect(result.voidReason, 'Duplicate entry');
    });

    test('propagates StateError when expense is not paid', () async {
      repo.voidError = StateError('Only paid expenses can be voided');
      await expectLater(
        () => useCase(
          expenseId: 'exp-pending',
          actorName: 'Finance A',
          actorUserId: 'fin-001',
          reason: 'Test',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('paid expenses'),
        )),
      );
    });

    test('propagates StateError when expense not found', () async {
      repo.voidError = StateError('Expense not found');
      await expectLater(
        () => useCase(
          expenseId: 'nonexistent',
          actorName: 'Finance A',
          actorUserId: 'fin-001',
          reason: 'Test',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
