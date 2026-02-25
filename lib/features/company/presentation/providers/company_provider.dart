import 'package:flutter/foundation.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/company_entity.dart';
import '../../domain/usecases/company_usecases.dart';

class CompanyProvider with ChangeNotifier {
  final GetCompanies getCompaniesUseCase;
  final GetCompanyById getCompanyByIdUseCase;
  final InsertCompany insertCompanyUseCase;
  final UpdateCompany updateCompanyUseCase;
  final DeleteCompany deleteCompanyUseCase;

  CompanyProvider({
    required this.getCompaniesUseCase,
    required this.getCompanyByIdUseCase,
    required this.insertCompanyUseCase,
    required this.updateCompanyUseCase,
    required this.deleteCompanyUseCase,
  });

  List<CompanyEntity> _companies = [];
  List<CompanyEntity> get companies => _companies;

  CompanyEntity? _selectedCompany;
  CompanyEntity? get selectedCompany => _selectedCompany;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadCompanies() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await getCompaniesUseCase(NoParams());

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _companies = [];
      },
      (companiesList) {
        _companies = companiesList;
        _errorMessage = null;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<CompanyEntity?> getCompanyById(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await getCompanyByIdUseCase(id);

    CompanyEntity? fetchedCompany;

    result.fold(
      (failure) {
        _errorMessage = failure.message;
        _selectedCompany = null;
      },
      (company) {
        _selectedCompany = company;
        fetchedCompany = company;
        _errorMessage = null;
      },
    );

    _isLoading = false;
    notifyListeners();
    return fetchedCompany;
  }

  Future<bool> insertCompany(CompanyEntity company) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await insertCompanyUseCase(company);

    bool isSuccess = false;

    result.fold(
      (failure) {
        _errorMessage = failure.message;
      },
      (_) {
        // Optimistically add to list and re-sort
        _companies.add(company);
        _companies.sort((a, b) => a.companyName.compareTo(b.companyName));
        _errorMessage = null;
        isSuccess = true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }

  Future<bool> updateCompany(CompanyEntity company) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await updateCompanyUseCase(company);

    bool isSuccess = false;

    result.fold(
      (failure) {
        _errorMessage = failure.message;
      },
      (_) {
        // Optimistically update list
        final index = _companies.indexWhere((c) => c.id == company.id);
        if (index != -1) {
          _companies[index] = company;
          _companies.sort((a, b) => a.companyName.compareTo(b.companyName));
        }
        _errorMessage = null;
        isSuccess = true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }

  Future<bool> deleteCompany(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await deleteCompanyUseCase(id);

    bool isSuccess = false;

    result.fold(
      (failure) {
        _errorMessage = failure.message;
      },
      (_) {
        // Optimistically remove from list
        _companies.removeWhere((c) => c.id == id);
        _errorMessage = null;
        isSuccess = true;
      },
    );

    _isLoading = false;
    notifyListeners();
    return isSuccess;
  }
}
