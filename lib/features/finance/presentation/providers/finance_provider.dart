import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/expense_category_entity.dart';
import '../../domain/usecases/get_all_expenses_usecase.dart';
import '../../domain/usecases/get_expenses_by_date_range_usecase.dart';
import '../../domain/usecases/get_expenses_by_account_usecase.dart';
import '../../domain/usecases/insert_expense_usecase.dart';
import '../../domain/usecases/update_expense_usecase.dart';
import '../../domain/usecases/delete_expense_usecase.dart';
import '../../domain/usecases/approve_expense_usecase.dart';
import '../../domain/usecases/reject_expense_usecase.dart';
import '../../domain/usecases/generate_reference_number_usecase.dart';
import '../../domain/usecases/upload_receipt_usecase.dart';
import '../../domain/usecases/get_expense_categories_usecase.dart';
import '../../domain/usecases/insert_expense_category_usecase.dart';
import '../../domain/usecases/update_expense_category_usecase.dart';
import '../../domain/usecases/delete_expense_category_usecase.dart';

/// Provider managing expense records and expense categories.
///
/// Handles CRUD operations, approval workflow, filtering,
/// and expense category configuration.
class FinanceProvider with ChangeNotifier {
  final GetAllExpensesUseCase getAllExpensesUseCase;
  final GetExpensesByDateRangeUseCase getExpensesByDateRangeUseCase;
  final GetExpensesByAccountUseCase getExpensesByAccountUseCase;
  final InsertExpenseUseCase insertExpenseUseCase;
  final UpdateExpenseUseCase updateExpenseUseCase;
  final DeleteExpenseUseCase deleteExpenseUseCase;
  final ApproveExpenseUseCase approveExpenseUseCase;
  final RejectExpenseUseCase rejectExpenseUseCase;
  final GenerateReferenceNumberUseCase generateReferenceNumberUseCase;
  final UploadReceiptUseCase uploadReceiptUseCase;
  final GetExpenseCategoriesUseCase getExpenseCategoriesUseCase;
  final InsertExpenseCategoryUseCase insertExpenseCategoryUseCase;
  final UpdateExpenseCategoryUseCase updateExpenseCategoryUseCase;
  final DeleteExpenseCategoryUseCase deleteExpenseCategoryUseCase;

  FinanceProvider({
    required this.getAllExpensesUseCase,
    required this.getExpensesByDateRangeUseCase,
    required this.getExpensesByAccountUseCase,
    required this.insertExpenseUseCase,
    required this.updateExpenseUseCase,
    required this.deleteExpenseUseCase,
    required this.approveExpenseUseCase,
    required this.rejectExpenseUseCase,
    required this.generateReferenceNumberUseCase,
    required this.uploadReceiptUseCase,
    required this.getExpenseCategoriesUseCase,
    required this.insertExpenseCategoryUseCase,
    required this.updateExpenseCategoryUseCase,
    required this.deleteExpenseCategoryUseCase,
  });

  // ─── State ──────────────────────────────────────────────────

  List<ExpenseEntity> _expenses = [];
  List<ExpenseCategoryEntity> _categories = [];
  bool _isLoading = false;
  bool _isCategoriesLoading = false;
  String? _error;

  // ─── Filters ────────────────────────────────────────────────

  ExpenseStatus? _statusFilter;
  String? _categoryFilter;
  String? _accountFilter;
  String? _searchQuery;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  // ─── Getters ────────────────────────────────────────────────

  List<ExpenseEntity> get expenses => _expenses;
  List<ExpenseCategoryEntity> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isCategoriesLoading => _isCategoriesLoading;
  String? get error => _error;
  ExpenseStatus? get statusFilter => _statusFilter;
  String? get categoryFilter => _categoryFilter;
  String? get accountFilter => _accountFilter;
  String? get searchQuery => _searchQuery;
  DateTime? get dateFrom => _dateFrom;
  DateTime? get dateTo => _dateTo;

  /// Filtered expenses based on current filter state.
  List<ExpenseEntity> get filteredExpenses {
    var result = List<ExpenseEntity>.from(_expenses);

    if (_statusFilter != null) {
      result = result.where((e) => e.status == _statusFilter).toList();
    }
    if (_categoryFilter != null && _categoryFilter!.isNotEmpty) {
      result = result
          .where((e) => e.expenseCategory == _categoryFilter)
          .toList();
    }
    if (_accountFilter != null && _accountFilter!.isNotEmpty) {
      result = result.where((e) => e.fundAccountId == _accountFilter).toList();
    }
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      final query = _searchQuery!.toLowerCase();
      result = result.where((e) {
        return e.referenceNumber.toLowerCase().contains(query) ||
            e.submittedBy.toLowerCase().contains(query) ||
            e.expenseType.toLowerCase().contains(query) ||
            (e.vehicleName?.toLowerCase().contains(query) ?? false) ||
            (e.employeeName?.toLowerCase().contains(query) ?? false) ||
            (e.description?.toLowerCase().contains(query) ?? false) ||
            (e.paymentDetails?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return result;
  }

  /// Count of expenses pending approval.
  int get pendingCount =>
      _expenses.where((e) => e.status == ExpenseStatus.pending).length;

  /// Total amount of all filtered expenses.
  double get totalFilteredAmount =>
      filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);

  // ─── Expense Operations ─────────────────────────────────────

  Future<void> fetchAllExpenses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _expenses = await getAllExpensesUseCase();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching expenses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchExpensesByDateRange(DateTime start, DateTime end) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _expenses = await getExpensesByDateRangeUseCase(start, end);
      _dateFrom = start;
      _dateTo = end;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching expenses by date range: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> insertExpense(ExpenseEntity expense) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await insertExpenseUseCase(expense);
      _expenses.insert(0, expense);
    } catch (e) {
      _error = e.toString();
      debugPrint('Error inserting expense: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateExpense(ExpenseEntity expense) async {
    _error = null;
    try {
      await updateExpenseUseCase(expense);
      final index = _expenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _expenses[index] = expense;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating expense: $e');
      notifyListeners();
    }
  }

  Future<void> deleteExpense(String id) async {
    _error = null;
    try {
      await deleteExpenseUseCase(id);
      _expenses.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting expense: $e');
      notifyListeners();
    }
  }

  Future<void> approveExpense(ExpenseEntity expense, String approvedBy) async {
    _error = null;
    try {
      await approveExpenseUseCase(expense, approvedBy);
      final index = _expenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _expenses[index] = expense.copyWith(
          status: ExpenseStatus.approved,
          approvedBy: approvedBy,
          approvedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error approving expense: $e');
      notifyListeners();
    }
  }

  Future<void> rejectExpense(
    ExpenseEntity expense,
    String rejectedBy,
    String reason,
  ) async {
    _error = null;
    try {
      await rejectExpenseUseCase(expense, rejectedBy, reason);
      final index = _expenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _expenses[index] = expense.copyWith(
          status: ExpenseStatus.rejected,
          approvedBy: rejectedBy,
          approvedAt: DateTime.now(),
          rejectionReason: reason,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error rejecting expense: $e');
      notifyListeners();
    }
  }

  Future<String> generateReferenceNumber() async {
    return await generateReferenceNumberUseCase();
  }

  Future<String> uploadReceipt(XFile file, String expenseId) async {
    return await uploadReceiptUseCase(file, expenseId);
  }

  // ─── Filter Operations ─────────────────────────────────────

  void setStatusFilter(ExpenseStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    _categoryFilter = category;
    notifyListeners();
  }

  void setAccountFilter(String? accountId) {
    _accountFilter = accountId;
    notifyListeners();
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = null;
    _categoryFilter = null;
    _accountFilter = null;
    _searchQuery = null;
    _dateFrom = null;
    _dateTo = null;
    notifyListeners();
  }

  // ─── Category Operations ────────────────────────────────────

  Future<void> fetchCategories() async {
    _isCategoriesLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await getExpenseCategoriesUseCase();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching categories: $e');
    } finally {
      _isCategoriesLoading = false;
      notifyListeners();
    }
  }

  Future<void> insertCategory(ExpenseCategoryEntity category) async {
    _error = null;
    try {
      await insertExpenseCategoryUseCase(category);
      _categories.add(category);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error inserting category: $e');
      notifyListeners();
    }
  }

  Future<void> updateCategory(ExpenseCategoryEntity category) async {
    _error = null;
    try {
      await updateExpenseCategoryUseCase(category);
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _categories[index] = category;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating category: $e');
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String id) async {
    _error = null;
    try {
      await deleteExpenseCategoryUseCase(id);
      _categories.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting category: $e');
      notifyListeners();
    }
  }

  /// Returns expense types for a given category name.
  List<ExpenseTypeEntity> getTypesForCategory(String categoryName) {
    final index = _categories.indexWhere((c) => c.name == categoryName);
    if (index == -1) return [];
    return _categories[index].expenseTypes.where((t) => t.isActive).toList();
  }
}
