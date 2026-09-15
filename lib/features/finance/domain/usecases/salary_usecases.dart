import '../entities/salary_entity.dart';
import '../repositories/finance_repository.dart';

class GetSalaryStructuresUseCase {
  final FinanceRepository repository;
  GetSalaryStructuresUseCase(this.repository);
  Future<List<SalaryStructureEntity>> call() => repository.getSalaryStructures();
}

class SaveSalaryStructureUseCase {
  final FinanceRepository repository;
  SaveSalaryStructureUseCase(this.repository);
  Future<SalaryStructureEntity> call(SalaryStructureEntity structure) =>
      repository.saveSalaryStructure(structure);
}

class DeleteSalaryStructureUseCase {
  final FinanceRepository repository;
  DeleteSalaryStructureUseCase(this.repository);
  Future<void> call(String employeeId) =>
      repository.deleteSalaryStructure(employeeId);
}

class GetSalaryPaymentsUseCase {
  final FinanceRepository repository;
  GetSalaryPaymentsUseCase(this.repository);
  Future<List<SalaryPaymentEntity>> call({String? period}) =>
      repository.getSalaryPayments(period: period);
}

class GenerateSalaryRunUseCase {
  final FinanceRepository repository;
  GenerateSalaryRunUseCase(this.repository);
  Future<List<SalaryPaymentEntity>> call({
    required String period,
    required String actorName,
    String? actorUserId,
  }) =>
      repository.generateSalaryRun(
        period: period,
        actorName: actorName,
        actorUserId: actorUserId,
      );
}

class SaveSalaryPaymentUseCase {
  final FinanceRepository repository;
  SaveSalaryPaymentUseCase(this.repository);
  Future<SalaryPaymentEntity> call(SalaryPaymentEntity payment) =>
      repository.saveSalaryPayment(payment);
}

class PaySalaryUseCase {
  final FinanceRepository repository;
  PaySalaryUseCase(this.repository);
  Future<SalaryPaymentEntity> call({
    required String paymentId,
    required String fundAccountId,
    required String actorName,
    String? actorUserId,
  }) =>
      repository.paySalary(
        paymentId: paymentId,
        fundAccountId: fundAccountId,
        actorName: actorName,
        actorUserId: actorUserId,
      );
}

class DeleteSalaryPaymentUseCase {
  final FinanceRepository repository;
  DeleteSalaryPaymentUseCase(this.repository);
  Future<void> call(String paymentId) =>
      repository.deleteSalaryPayment(paymentId);
}

class VoidSalaryPaymentUseCase {
  final FinanceRepository repository;
  VoidSalaryPaymentUseCase(this.repository);
  Future<SalaryPaymentEntity> call({
    required String paymentId,
    required String reason,
    required String actorName,
    String? actorUserId,
  }) =>
      repository.voidSalaryPayment(
        paymentId: paymentId,
        reason: reason,
        actorName: actorName,
        actorUserId: actorUserId,
      );
}
