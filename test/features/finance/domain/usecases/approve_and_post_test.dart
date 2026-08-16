import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/domain/entities/expense_entity.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/approve_expense_usecase.dart';

import 'test_finance_repository.dart';

void main() {
  late FakeFinanceRepository repo;
  late ApproveExpenseUseCase useCase;

  setUp(() {
    repo = FakeFinanceRepository();
    useCase = ApproveExpenseUseCase(repo);
  });

  ExpenseEntity pendingExpense({
    String id = 'exp-001',
    double amount = 500,
    String submittedByUserId = 'user-A',
  }) =>
      ExpenseEntity(
        id: id,
        referenceNumber: '#10001',
        date: DateTime(2025, 1, 15),
        createdAt: DateTime(2025, 1, 15),
        submittedBy: 'Driver A',
        submittedByRole: 'driver',
        submittedByUserId: submittedByUserId,
        expenseCategory: 'Fuel',
        expenseType: 'Regular Fuel',
        paymentMethod: 'cash',
        amount: amount,
        currency: 'SAR',
        fundAccountId: 'acc-001',
        status: ExpenseStatus.pending,
      );

  group('ApproveExpenseUseCase', () {
    test('returns paid expense on success', () async {
      final expense = pendingExpense();
      repo.approveResult = expense.copyWith(status: ExpenseStatus.paid);

      final result = await useCase(
        expenseId: expense.id,
        actorName: 'Manager A',
        actorUserId: 'mgr-001',
        actorRole: 'manager',
      );
      expect(result.status, ExpenseStatus.paid);
    });

    test('propagates StateError from double-approve', () async {
      repo.approveError = StateError('Expense cannot be paid from status paid');
      await expectLater(
        () => useCase(
          expenseId: 'exp-001',
          actorName: 'Manager A',
          actorUserId: 'mgr-001',
          actorRole: 'manager',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('propagates StateError from overdraw', () async {
      repo.approveError = StateError('Insufficient fund balance');
      await expectLater(
        () => useCase(
          expenseId: 'exp-001',
          actorName: 'Manager A',
          actorUserId: 'mgr-001',
          actorRole: 'manager',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Insufficient'),
        )),
      );
    });

    test('propagates StateError from self-approve block', () async {
      repo.approveError = StateError('Cannot approve your own expense');
      await expectLater(
        () => useCase(
          expenseId: 'exp-001',
          actorName: 'Driver A',
          actorUserId: 'user-A',
          actorRole: 'driver',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('own expense'),
        )),
      );
    });

    test('propagates StateError from day lock', () async {
      repo.approveError = StateError('Day 2025-01-15 is locked');
      await expectLater(
        () => useCase(
          expenseId: 'exp-001',
          actorName: 'Manager A',
          actorUserId: 'mgr-001',
          actorRole: 'manager',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('locked'),
        )),
      );
    });

    test('propagates StateError for insufficient cash bucket', () async {
      repo.approveError = StateError('Insufficient cash balance');
      await expectLater(
        () => useCase(
          expenseId: 'exp-001',
          actorName: 'Manager A',
          actorUserId: 'mgr-001',
          actorRole: 'manager',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
