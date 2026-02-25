import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/company_entity.dart';
import '../repositories/company_repository.dart';

class GetCompanies implements UseCase<List<CompanyEntity>, NoParams> {
  final CompanyRepository repository;

  GetCompanies(this.repository);

  @override
  Future<Either<Failure, List<CompanyEntity>>> call(NoParams params) async {
    return await repository.getCompanies();
  }
}

class GetCompanyById implements UseCase<CompanyEntity?, String> {
  final CompanyRepository repository;

  GetCompanyById(this.repository);

  @override
  Future<Either<Failure, CompanyEntity?>> call(String params) async {
    return await repository.getCompanyById(params);
  }
}

class InsertCompany implements UseCase<void, CompanyEntity> {
  final CompanyRepository repository;

  InsertCompany(this.repository);

  @override
  Future<Either<Failure, void>> call(CompanyEntity params) async {
    return await repository.insertCompany(params);
  }
}

class UpdateCompany implements UseCase<void, CompanyEntity> {
  final CompanyRepository repository;

  UpdateCompany(this.repository);

  @override
  Future<Either<Failure, void>> call(CompanyEntity params) async {
    return await repository.updateCompany(params);
  }
}

class DeleteCompany implements UseCase<void, String> {
  final CompanyRepository repository;

  DeleteCompany(this.repository);

  @override
  Future<Either<Failure, void>> call(String params) async {
    return await repository.deleteCompany(params);
  }
}
