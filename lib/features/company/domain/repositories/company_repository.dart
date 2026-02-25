import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/company_entity.dart';

abstract class CompanyRepository {
  Future<Either<Failure, List<CompanyEntity>>> getCompanies();
  Future<Either<Failure, CompanyEntity?>> getCompanyById(String id);
  Future<Either<Failure, void>> insertCompany(CompanyEntity company);
  Future<Either<Failure, void>> updateCompany(CompanyEntity company);
  Future<Either<Failure, void>> deleteCompany(String id);
}
