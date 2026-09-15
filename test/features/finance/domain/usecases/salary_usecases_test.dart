import 'package:flutter_test/flutter_test.dart';
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

    test('period key and document id are deterministic', () {
      expect(SalaryPaymentEntity.periodOf(DateTime(2026, 9, 15)), '2026-09');
      expect(SalaryPaymentEntity.buildId('2026-09', 'emp1'), '2026-09_emp1');
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
