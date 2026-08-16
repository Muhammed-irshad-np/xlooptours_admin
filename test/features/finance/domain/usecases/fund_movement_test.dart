import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_transaction_entity.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/insert_transaction_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/transfer_funds_usecase.dart';

import 'test_finance_repository.dart';

void main() {
  late FakeFinanceRepository repo;

  setUp(() => repo = FakeFinanceRepository());

  FundTransactionEntity fakeTx({
    bool isDeposit = true,
    double balBefore = 1000,
    double amount = 200,
  }) =>
      FundTransactionEntity(
        id: 'tx-001',
        fundAccountId: 'acc-001',
        type: isDeposit ? FundTransactionType.deposit : FundTransactionType.withdrawal,
        amount: amount,
        currency: 'SAR',
        description: 'Test',
        performedBy: 'Finance A',
        date: DateTime(2025, 1, 15),
        createdAt: DateTime(2025, 1, 15),
        balanceBefore: balBefore,
        balanceAfter: isDeposit ? balBefore + amount : balBefore - amount,
      );

  group('InsertTransactionUseCase (postFundMovement)', () {
    test('deposit: balanceAfter > balanceBefore', () async {
      final useCase = InsertTransactionUseCase(repo);
      repo.fundMovementResult = fakeTx(isDeposit: true, balBefore: 1000, amount: 200);

      final result = await useCase(
        fundAccountId: 'acc-001',
        type: FundTransactionType.deposit,
        amountMajor: 200,
        currency: 'SAR',
        description: 'Top up',
        performedBy: 'Finance A',
        performedByUserId: 'fin-001',
      );

      expect(result.type, FundTransactionType.deposit);
      expect(result.balanceAfter, greaterThan(result.balanceBefore));
      expect(result.balanceAfter, closeTo(1200, 0.001));
    });

    test('withdrawal: balanceAfter < balanceBefore', () async {
      final useCase = InsertTransactionUseCase(repo);
      repo.fundMovementResult = fakeTx(isDeposit: false, balBefore: 1000, amount: 300);

      final result = await useCase(
        fundAccountId: 'acc-001',
        type: FundTransactionType.withdrawal,
        amountMajor: 300,
        currency: 'SAR',
        description: 'Cash withdrawal',
        performedBy: 'Finance A',
        performedByUserId: 'fin-001',
      );

      expect(result.balanceAfter, lessThan(result.balanceBefore));
      expect(result.balanceAfter, closeTo(700, 0.001));
    });

    test('propagates StateError on overdraw', () async {
      final useCase = InsertTransactionUseCase(repo);
      repo.fundMovementError = StateError('Insufficient fund balance');
      await expectLater(
        () => useCase(
          fundAccountId: 'acc-001',
          type: FundTransactionType.withdrawal,
          amountMajor: 999999,
          currency: 'SAR',
          description: 'Overdraw attempt',
          performedBy: 'Finance A',
          performedByUserId: 'fin-001',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Insufficient'),
        )),
      );
    });

    test('propagates StateError on day-locked account', () async {
      final useCase = InsertTransactionUseCase(repo);
      repo.fundMovementError = StateError('Day 2025-01-15 is locked');
      await expectLater(
        () => useCase(
          fundAccountId: 'acc-001',
          type: FundTransactionType.deposit,
          amountMajor: 500,
          currency: 'SAR',
          description: 'Deposit on locked day',
          performedBy: 'Finance A',
          performedByUserId: 'fin-001',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('locked'),
        )),
      );
    });
  });

  group('TransferFundsUseCase', () {
    test('completes without error on valid transfer', () async {
      final useCase = TransferFundsUseCase(repo);
      await expectLater(
        useCase(
          fromAccountId: 'acc-001',
          toAccountId: 'acc-002',
          amountMajor: 500,
          currency: 'SAR',
          description: 'Transfer to driver fund',
          performedBy: 'Finance A',
          performedByUserId: 'fin-001',
        ),
        completes,
      );
    });

    test('propagates ArgumentError on same-account transfer', () async {
      final useCase = TransferFundsUseCase(repo);
      repo.transferError = ArgumentError('Cannot transfer to the same account');
      await expectLater(
        () => useCase(
          fromAccountId: 'acc-001',
          toAccountId: 'acc-001',
          amountMajor: 100,
          currency: 'SAR',
          description: 'Self-transfer',
          performedBy: 'Finance A',
          performedByUserId: 'fin-001',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('propagates StateError on insufficient source balance', () async {
      final useCase = TransferFundsUseCase(repo);
      repo.transferError = StateError('Insufficient balance on source account');
      await expectLater(
        () => useCase(
          fromAccountId: 'acc-001',
          toAccountId: 'acc-002',
          amountMajor: 999999,
          currency: 'SAR',
          description: 'Overdraw transfer',
          performedBy: 'Finance A',
          performedByUserId: 'fin-001',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Insufficient'),
        )),
      );
    });
  });

  group('Money arithmetic', () {
    test('balanceAfter for deposit = balanceBefore + amount', () {
      const balBefore = 1000.0;
      const amount = 250.0;
      final tx = FundTransactionEntity(
        id: 'tx-001',
        fundAccountId: 'acc-001',
        type: FundTransactionType.deposit,
        amount: amount,
        currency: 'SAR',
        description: 'Top up',
        performedBy: 'Finance A',
        date: DateTime(2025, 1, 15),
        createdAt: DateTime(2025, 1, 15),
        balanceBefore: balBefore,
        balanceAfter: balBefore + amount,
      );
      expect(tx.balanceAfter, closeTo(balBefore + amount, 0.001));
    });

    test('amountMinor roundtrip has no drift for common SAR amounts', () {
      for (final sar in [1.0, 50.0, 100.0, 1234.0, 9999.99]) {
        final minor = (sar * 100).round();
        final back = minor / 100.0;
        expect(back, closeTo(sar, 0.001),
            reason: 'Roundtrip failed for $sar SAR');
      }
    });
  });
}
