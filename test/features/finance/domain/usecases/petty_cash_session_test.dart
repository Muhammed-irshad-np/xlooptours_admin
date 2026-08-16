import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/domain/entities/petty_cash_session_entity.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/close_petty_cash_session_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/open_petty_cash_session_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/verify_petty_cash_session_usecase.dart';

import 'test_finance_repository.dart';

void main() {
  late FakeFinanceRepository repo;

  setUp(() => repo = FakeFinanceRepository());

  PettyCashSessionEntity openSession({
    double openingCash = 1000.0,
    double openingStc = 500.0,
  }) =>
      PettyCashSessionEntity(
        id: 'sess-001',
        fundAccountId: 'acc-001',
        date: DateTime(2025, 1, 15),
        openedBy: 'Coordinator A',
        openingCashBalance: openingCash,
        openingStcPayBalance: openingStc,
        createdAt: DateTime(2025, 1, 15),
        status: PettyCashSessionStatus.open,
      );

  group('OpenPettyCashSessionUseCase', () {
    test('calls repo.openPettyCashSession and returns normally', () async {
      final useCase = OpenPettyCashSessionUseCase(repo);
      await expectLater(useCase(openSession()), completes);
    });

    test('propagates StateError when open session already exists', () async {
      repo.openSessionError = StateError('An open session already exists');
      final useCase = OpenPettyCashSessionUseCase(repo);
      await expectLater(
        () => useCase(openSession()),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already exists'),
        )),
      );
    });
  });

  group('ClosePettyCashSessionUseCase', () {
    test('returns closed session with ledger-computed deposits/expenses', () async {
      final useCase = ClosePettyCashSessionUseCase(repo);
      final session = openSession(openingCash: 1000, openingStc: 500);
      repo.closeResult = session.copyWith(
        status: PettyCashSessionStatus.closed,
        cashDeposits: 200,
        stcPayDeposits: 100,
        cashExpenses: 350,
        stcPayExpenses: 80,
        discrepancy: -30.0,
        closedBy: 'Coordinator A',
      );

      final result = await useCase(
        session: session,
        closedBy: 'Coordinator A',
        closedByUserId: 'coord-001',
      );

      expect(result.status, PettyCashSessionStatus.closed);
      expect(result.cashDeposits, 200.0);
      expect(result.cashExpenses, 350.0);
      // Expected closing = (1000+200-350) + (500+100-80) = 850 + 520 = 1370
      expect(result.expectedClosingBalance, closeTo(1370.0, 0.01));
    });

    test('propagates StateError when session is not open', () async {
      repo.closeSessionError = StateError('Only open sessions can be closed');
      final useCase = ClosePettyCashSessionUseCase(repo);
      final closedAlready = openSession().copyWith(status: PettyCashSessionStatus.closed);
      await expectLater(
        () => useCase(
          session: closedAlready,
          closedBy: 'Coordinator A',
          closedByUserId: 'coord-001',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('VerifyPettyCashSessionUseCase', () {
    test('completes without error on valid closed session', () async {
      final useCase = VerifyPettyCashSessionUseCase(repo);
      await expectLater(
        useCase(
          sessionId: 'sess-001',
          verifiedBy: 'Finance A',
          verifiedByUserId: 'fin-001',
        ),
        completes,
      );
    });

    test('propagates StateError when session is not closed', () async {
      repo.verifySessionError = StateError('Only closed sessions can be verified');
      final useCase = VerifyPettyCashSessionUseCase(repo);
      await expectLater(
        () => useCase(
          sessionId: 'sess-open',
          verifiedBy: 'Finance A',
          verifiedByUserId: 'fin-001',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('closed sessions'),
        )),
      );
    });
  });

  group('PettyCashSessionEntity math', () {
    test('expectedClosingBalance sums opening + deposits - expenses', () {
      final session = PettyCashSessionEntity(
        id: 'sess-001',
        fundAccountId: 'acc-001',
        date: DateTime(2025, 1, 15),
        createdAt: DateTime(2025, 1, 15),
        openingCashBalance: 1000,
        openingStcPayBalance: 500,
        cashDeposits: 300,
        stcPayDeposits: 0,
        cashExpenses: 450,
        stcPayExpenses: 150,
      );
      // Cash: 1000 + 300 - 450 = 850
      expect(session.expectedCashClosing, closeTo(850, 0.01));
      // STC: 500 + 0 - 150 = 350
      expect(session.expectedStcPayClosing, closeTo(350, 0.01));
      // Total: 1200
      expect(session.expectedClosingBalance, closeTo(1200, 0.01));
    });

    test('negative discrepancy means cash shortfall', () {
      final session = PettyCashSessionEntity(
        id: 'sess-001',
        fundAccountId: 'acc-001',
        date: DateTime(2025, 1, 15),
        createdAt: DateTime(2025, 1, 15),
        openingCashBalance: 1000,
        openingStcPayBalance: 0,
        cashDeposits: 200,
        stcPayDeposits: 0,
        cashExpenses: 300,
        stcPayExpenses: 0,
        closingBalance: 850,
        discrepancy: -50,
      );
      expect(session.expectedClosingBalance, closeTo(900, 0.01));
      expect(session.discrepancy, closeTo(-50, 0.01));
    });
  });
}
