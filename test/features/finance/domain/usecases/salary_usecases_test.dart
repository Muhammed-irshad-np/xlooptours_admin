import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/domain/entities/cash_advance_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/salary_entity.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/salary_usecases.dart';
import 'test_finance_repository.dart';

SalaryStructureEntity _structure({
  required String employeeId,
  String name = 'Employee',
  double basic = 3000,
  double allowances = 500,
  bool isActive = true,
}) {
  return SalaryStructureEntity(
    employeeId: employeeId,
    employeeName: name,
    basicSalary: basic,
    allowances: allowances,
    isActive: isActive,
    updatedAt: DateTime(2026, 9, 1),
  );
}

CashAdvanceEntity _advance({
  required String id,
  required double amount,
  double settled = 0,
  int issuedDaysAgo = 30,
  CashAdvanceStatus status = CashAdvanceStatus.open,
}) {
  final issued = DateTime(2026, 9, 1).subtract(Duration(days: issuedDaysAgo));
  return CashAdvanceEntity(
    id: id,
    fundAccountId: 'acc1',
    employeeId: 'emp1',
    employeeName: 'Ali',
    amount: amount,
    settledAmount: settled,
    currency: 'SAR',
    purpose: 'Fuel float',
    status: status,
    issuedBy: 'Admin',
    issuedAt: issued,
    createdAt: issued,
  );
}

void main() {
  group('SalaryPaymentEntity maths', () {
    test('net pay is gross minus deductions', () {
      expect(
        SalaryPaymentEntity.computeNet(
          basicSalary: 3000,
          allowances: 500,
          deductions: 200,
        ),
        3300,
      );
    });

    test('net pay never goes below zero', () {
      expect(
        SalaryPaymentEntity.computeNet(
          basicSalary: 1000,
          allowances: 0,
          deductions: 4000,
        ),
        0,
      );
    });

    test('advance recovery reduces net pay like a deduction', () {
      expect(
        SalaryPaymentEntity.computeNet(
          basicSalary: 3000,
          allowances: 500,
          deductions: 200,
          advanceRecovery: 800,
        ),
        2500,
      );
    });

    test('net floors at zero when an advance swallows the whole salary', () {
      expect(
        SalaryPaymentEntity.computeNet(
          basicSalary: 2000,
          allowances: 0,
          advanceRecovery: 2500,
        ),
        0,
      );
    });

    test('period key and document id are deterministic', () {
      expect(SalaryPaymentEntity.periodOf(DateTime(2026, 9, 15)), '2026-09');
      expect(SalaryPaymentEntity.buildId('2026-09', 'emp1'), '2026-09_emp1');
    });
  });

  group('Advance recovery allocation', () {
    test('settles the oldest advance first', () {
      final result = SalaryPaymentEntity.allocateAdvanceRecovery(
        amount: 400,
        advances: [
          _advance(id: 'new', amount: 1000, issuedDaysAgo: 5),
          _advance(id: 'old', amount: 1000, issuedDaysAgo: 90),
        ],
      );

      expect(result, {'old': 400.0});
    });

    test('spills over into the next advance once the first is cleared', () {
      final result = SalaryPaymentEntity.allocateAdvanceRecovery(
        amount: 1200,
        advances: [
          _advance(id: 'old', amount: 1000, issuedDaysAgo: 90),
          _advance(id: 'new', amount: 1000, issuedDaysAgo: 5),
        ],
      );

      expect(result, {'old': 1000.0, 'new': 200.0});
    });

    test('respects what is already settled on an advance', () {
      final result = SalaryPaymentEntity.allocateAdvanceRecovery(
        amount: 500,
        advances: [
          _advance(
            id: 'part',
            amount: 1000,
            settled: 700,
            status: CashAdvanceStatus.partiallySettled,
          ),
        ],
      );

      expect(result, {'part': 300.0});
    });

    test('skips advances that are already settled or written off', () {
      final result = SalaryPaymentEntity.allocateAdvanceRecovery(
        amount: 500,
        advances: [
          _advance(
            id: 'done',
            amount: 1000,
            settled: 1000,
            status: CashAdvanceStatus.settled,
          ),
          _advance(
            id: 'gone',
            amount: 500,
            status: CashAdvanceStatus.writtenOff,
          ),
        ],
      );

      expect(result, isEmpty);
    });

    test('allocates nothing for a zero or negative amount', () {
      final advances = [_advance(id: 'a1', amount: 1000)];
      expect(
        SalaryPaymentEntity.allocateAdvanceRecovery(
          amount: 0,
          advances: advances,
        ),
        isEmpty,
      );
      expect(
        SalaryPaymentEntity.allocateAdvanceRecovery(
          amount: -50,
          advances: advances,
        ),
        isEmpty,
      );
    });

    test('totalOutstanding only counts open advances', () {
      expect(
        SalaryPaymentEntity.totalOutstanding([
          _advance(id: 'a1', amount: 1000, settled: 250),
          _advance(
            id: 'a2',
            amount: 500,
            settled: 500,
            status: CashAdvanceStatus.settled,
          ),
        ]),
        750,
      );
    });
  });

  group('Salary use cases', () {
    late FakeFinanceRepository fakeRepo;
    late GetSalaryStructuresUseCase getStructures;
    late SaveSalaryStructureUseCase saveStructure;
    late DeleteSalaryStructureUseCase deleteStructure;
    late GetSalaryPaymentsUseCase getPayments;
    late GenerateSalaryRunUseCase generateRun;
    late PaySalaryUseCase paySalary;
    late VoidSalaryPaymentUseCase voidPayment;

    setUp(() {
      fakeRepo = FakeFinanceRepository();
      getStructures = GetSalaryStructuresUseCase(fakeRepo);
      saveStructure = SaveSalaryStructureUseCase(fakeRepo);
      deleteStructure = DeleteSalaryStructureUseCase(fakeRepo);
      getPayments = GetSalaryPaymentsUseCase(fakeRepo);
      generateRun = GenerateSalaryRunUseCase(fakeRepo);
      paySalary = PaySalaryUseCase(fakeRepo);
      voidPayment = VoidSalaryPaymentUseCase(fakeRepo);
    });

    test('saving a structure puts the employee on the payroll', () async {
      await saveStructure(_structure(employeeId: 'emp1', name: 'Ali'));
      final all = await getStructures();

      expect(all.length, 1);
      expect(all.first.employeeName, 'Ali');
      expect(all.first.grossSalary, 3500);
    });

    test('deleting a structure takes the employee off the payroll', () async {
      await saveStructure(_structure(employeeId: 'emp1'));
      await deleteStructure('emp1');

      expect(await getStructures(), isEmpty);
    });

    test('generating a month creates one pending row per active employee',
        () async {
      await saveStructure(_structure(employeeId: 'emp1', name: 'Ali'));
      await saveStructure(
        _structure(employeeId: 'emp2', name: 'Sara', basic: 4000),
      );
      await saveStructure(
        _structure(employeeId: 'emp3', name: 'Inactive', isActive: false),
      );

      final run = await generateRun(period: '2026-09', actorName: 'Admin');

      expect(run.length, 2);
      expect(run.every((p) => p.status == SalaryPaymentStatus.pending), isTrue);
      expect(
        run.firstWhere((p) => p.employeeId == 'emp2').netAmount,
        4500,
      );
    });

    test('generating the same month twice does not duplicate rows', () async {
      await saveStructure(_structure(employeeId: 'emp1'));

      await generateRun(period: '2026-09', actorName: 'Admin');
      final second = await generateRun(period: '2026-09', actorName: 'Admin');

      expect(second.length, 1);
      expect((await getPayments(period: '2026-09')).length, 1);
    });

    test('a generated month only returns rows of that month', () async {
      await saveStructure(_structure(employeeId: 'emp1'));
      await generateRun(period: '2026-09', actorName: 'Admin');
      await generateRun(period: '2026-10', actorName: 'Admin');

      expect((await getPayments(period: '2026-09')).length, 1);
      expect((await getPayments()).length, 2);
    });

    test('paying a salary passes the row and the source account through',
        () async {
      await saveStructure(_structure(employeeId: 'emp1', name: 'Ali'));
      final run = await generateRun(period: '2026-09', actorName: 'Admin');
      final pending = run.first;
      fakeRepo.paySalaryResult = pending.copyWith(
        status: SalaryPaymentStatus.paid,
        fundAccountId: 'acc1',
        ledgerEntryId: 'tx1',
      );

      final paid = await paySalary(
        paymentId: pending.id,
        fundAccountId: 'acc1',
        actorName: 'Admin',
      );

      expect(fakeRepo.lastPaidSalaryId, pending.id);
      expect(fakeRepo.lastPaidFromAccountId, 'acc1');
      expect(paid.status, SalaryPaymentStatus.paid);
      expect(paid.ledgerEntryId, 'tx1');
    });

    test('paying forwards the wallet bucket and advance recoveries', () async {
      await saveStructure(_structure(employeeId: 'emp1'));
      final run = await generateRun(period: '2026-09', actorName: 'Admin');
      final pending = run.first;
      fakeRepo.paySalaryResult =
          pending.copyWith(status: SalaryPaymentStatus.paid);

      await paySalary(
        paymentId: pending.id,
        fundAccountId: 'acc1',
        actorName: 'Admin',
        paymentMethod: 'stcPay',
        advanceRecoveries: const {'adv1': 300},
      );

      expect(fakeRepo.lastPaidMethod, 'stcPay');
      expect(fakeRepo.lastAdvanceRecoveries, {'adv1': 300.0});
    });

    test('voiding a paid salary records the reason', () async {
      await saveStructure(_structure(employeeId: 'emp1'));
      final run = await generateRun(period: '2026-09', actorName: 'Admin');

      final voided = await voidPayment(
        paymentId: run.first.id,
        reason: 'paid twice',
        actorName: 'Admin',
      );

      expect(voided.status, SalaryPaymentStatus.voided);
      expect(voided.voidReason, 'paid twice');
      expect(voided.status.canPay, isFalse);
    });

    test('errors from the repository surface to the caller', () async {
      fakeRepo.salaryError = StateError('boom');

      expect(() => getStructures(), throwsStateError);
    });
  });
}
