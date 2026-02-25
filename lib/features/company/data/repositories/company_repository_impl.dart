import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/company_entity.dart';
import '../../domain/repositories/company_repository.dart';
import '../datasources/company_remote_data_source.dart';
import '../models/company_model.dart';

class CompanyRepositoryImpl implements CompanyRepository {
  final CompanyRemoteDataSource remoteDataSource;

  CompanyRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<CompanyEntity>>> getCompanies() async {
    try {
      final companies = await remoteDataSource.getCompanies();
      return Right(companies);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CompanyEntity?>> getCompanyById(String id) async {
    try {
      final company = await remoteDataSource.getCompanyById(id);
      return Right(company);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> insertCompany(CompanyEntity company) async {
    try {
      final model = CompanyModel(
        id: company.id,
        companyName: company.companyName,
        email: company.email,
        country: company.country,
        vatRegisteredInKSA: company.vatRegisteredInKSA,
        taxRegistrationNumber: company.taxRegistrationNumber,
        city: company.city,
        streetAddress: company.streetAddress,
        buildingNumber: company.buildingNumber,
        district: company.district,
        addressAdditionalNumber: company.addressAdditionalNumber,
        postalCode: company.postalCode,
        usesCaseCode: company.usesCaseCode,
        caseCodeLabel: company.caseCodeLabel,
        caseCodes: company.caseCodes,
        status: company.status,
        createdAt: company.createdAt,
      );
      await remoteDataSource.insertCompany(model);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateCompany(CompanyEntity company) async {
    try {
      final model = CompanyModel(
        id: company.id,
        companyName: company.companyName,
        email: company.email,
        country: company.country,
        vatRegisteredInKSA: company.vatRegisteredInKSA,
        taxRegistrationNumber: company.taxRegistrationNumber,
        city: company.city,
        streetAddress: company.streetAddress,
        buildingNumber: company.buildingNumber,
        district: company.district,
        addressAdditionalNumber: company.addressAdditionalNumber,
        postalCode: company.postalCode,
        usesCaseCode: company.usesCaseCode,
        caseCodeLabel: company.caseCodeLabel,
        caseCodes: company.caseCodes,
        status: company.status,
        createdAt: company.createdAt,
      );
      await remoteDataSource.updateCompany(model);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteCompany(String id) async {
    try {
      await remoteDataSource.deleteCompany(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
