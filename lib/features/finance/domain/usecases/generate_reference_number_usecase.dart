import '../repositories/finance_repository.dart';

/// Generates the next sequential reference number for a new expense.
class GenerateReferenceNumberUseCase {
  final FinanceRepository repository;

  GenerateReferenceNumberUseCase(this.repository);

  Future<String> call() async {
    return await repository.generateReferenceNumber();
  }
}
