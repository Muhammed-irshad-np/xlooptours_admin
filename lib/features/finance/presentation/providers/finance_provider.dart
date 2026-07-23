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
import '../../domain/usecases/void_expense_usecase.dart';
import '../../domain/usecases/generate_reference_number_usecase.dart';
import '../../domain/usecases/upload_receipt_usecase.dart';
import '../../domain/usecases/get_expense_categories_usecase.dart';
import '../../domain/usecases/insert_expense_category_usecase.dart';
import '../../domain/usecases/update_expense_category_usecase.dart';
import '../../domain/usecases/delete_expense_category_usecase.dart';

/// Provider managing expenses and categories.
class FinanceProvider with ChangeNotifier {
  final GetAllExpensesUseCase getAllExpensesUseCase;
  final GetExpensesByDateRangeUseCase getExpensesByDateRangeUseCase;
  final GetExpensesByAccountUseCase getExpensesByAccountUseCase;
  final InsertExpenseUseCase insertExpenseUseCase;
  final UpdateExpenseUseCase updateExpenseUseCase;
  final DeleteExpenseUseCase deleteExpenseUseCase;
  final ApproveExpenseUseCase approveExpenseUseCase;
  final RejectExpenseUseCase rejectExpenseUseCase;
  final VoidExpenseUseCase voidExpenseUseCase;
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
    required this.voidExpenseUseCase,
    required this.generateReferenceNumberUseCase,
    required this.uploadReceiptUseCase,
    required this.getExpenseCategoriesUseCase,
    required this.insertExpenseCategoryUseCase,
    required this.updateExpenseCategoryUseCase,
    required this.deleteExpenseCategoryUseCase,
  });

  List<ExpenseEntity> _expenses = [];
  List<ExpenseCategoryEntity> _categories = [];
  bool _isLoading = false;
  bool _isCategoriesLoading = false;
  String? _error;

  ExpenseStatus? _statusFilter;
  String? _categoryFilter;
  String? _accountFilter;
  String? _searchQuery;
  DateTime? _dateFrom;
  DateTime? _dateTo;

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

  List<ExpenseEntity> get filteredExpenses {
    var result = List<ExpenseEntity>.from(_expenses);

    if (_statusFilter != null) {
      result = result.where((e) => e.status == _statusFilter).toList();
    }
    if (_categoryFilter != null && _categoryFilter!.isNotEmpty) {
      result =
          result.where((e) => e.expenseCategory == _categoryFilter).toList();
    }
    if (_accountFilter != null && _accountFilter!.isNotEmpty) {
      result =
          result.where((e) => e.fundAccountId == _accountFilter).toList();
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

  int get pendingCount =>
      _expenses.where((e) => e.status == ExpenseStatus.pending).length;

  double get totalFilteredAmount =>
      filteredExpenses.fold(0.0, (sum, e) => sum + e.amount);

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
    _error = null;
    final withMinor = expense.copyWith(
      amountMinor: expense.amountMinor ?? (expense.amount * 100).round(),
    );
    _expenses = [withMinor, ..._expenses];
    notifyListeners();

    try {
      await insertExpenseUseCase(withMinor);
    } catch (e) {
      _expenses = _expenses.where((e) => e.id != withMinor.id).toList();
      _error = e.toString();
      debugPrint('Error inserting expense: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateExpense(ExpenseEntity expense) async {
    _error = null;
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    ExpenseEntity? oldExpense;

    if (index != -1) {
      oldExpense = _expenses[index];
      _expenses[index] = expense;
      notifyListeners();
    }

    try {
      await updateExpenseUseCase(expense);
    } catch (e) {
      if (index != -1 && oldExpense != null) {
        _expenses[index] = oldExpense;
      }
      _error = e.toString();
      debugPrint('Error updating expense: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Only drafts/pending. Posted expenses must be voided.
  Future<void> deleteExpense(String id) async {
    _error = null;
    final index = _expenses.indexWhere((e) => e.id == id);
    ExpenseEntity? oldExpense;

    if (index != -1) {
      oldExpense = _expenses[index];
      if (!oldExpense.status.canHardDelete) {
        _error =
            'Cannot delete posted expense. Void it to reverse the payment.';
        notifyListeners();
        throw StateError(_error!);
      }
      _expenses.removeAt(index);
      notifyListeners();
    }

    try {
      await deleteExpenseUseCase(id);
    } catch (e) {
      if (index != -1 && oldExpense != null) {
        _expenses.insert(index, oldExpense);
      }
      _error = e.toString();
      debugPrint('Error deleting expense: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Approve + post to wallet (or approve only if non-wallet).
  Future<void> approveExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String actorRole,
    bool allowSelfApprove = false,
  }) async {
    _error = null;
    try {
      final updated = await approveExpenseUseCase(
        expenseId: expenseId,
        actorName: actorName,
        actorUserId: actorUserId,
        actorRole: actorRole,
        allowSelfApprove: allowSelfApprove,
      );
      final index = _expenses.indexWhere((e) => e.id == expenseId);
      if (index != -1) {
        _expenses[index] = updated;
      } else {
        _expenses = [updated, ..._expenses];
      }
      notifyListeners();
    } catch (e, st) {
      _error = _readableError(e);
      debugPrint('Error approving expense: $_error');
      debugPrint('Approve raw: $e');
      debugPrint('Approve stack: $st');
      notifyListeners();
      throw StateError(_error!);
    }
  }

  String _readableError(Object e) {
    final s = e.toString();
    if (s.contains('Dart exception thrown from converted Future')) {
      try {
        // ignore: avoid_dynamic_calls
        final dynamic d = e;
        final inner = d.error ?? d.message;
        if (inner != null && '$inner'.isNotEmpty) {
          return '$inner';
        }
      } catch (_) {}
      return 'Approve failed (web hid the real error). Common causes: '
          'insufficient fund/cash balance, day locked, approval limit, '
          'or Firestore permission-denied. Check fund balance and your role.';
    }
    return s
        .replaceFirst('StateError: ', '')
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }

  Future<void> rejectExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String reason,
  }) async {
    _error = null;
    try {
      final updated = await rejectExpenseUseCase(
        expenseId: expenseId,
        actorName: actorName,
        actorUserId: actorUserId,
        reason: reason,
      );
      final index = _expenses.indexWhere((e) => e.id == expenseId);
      if (index != -1) {
        _expenses[index] = updated;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error rejecting expense: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> voidExpense({
    required String expenseId,
    required String actorName,
    required String actorUserId,
    required String reason,
  }) async {
    _error = null;
    try {
      final updated = await voidExpenseUseCase(
        expenseId: expenseId,
        actorName: actorName,
        actorUserId: actorUserId,
        reason: reason,
      );
      final index = _expenses.indexWhere((e) => e.id == expenseId);
      if (index != -1) {
        _expenses[index] = updated;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error voiding expense: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<String> generateReferenceNumber() async {
    return await generateReferenceNumberUseCase();
  }

  Future<String> uploadReceipt(XFile file, String expenseId) async {
    return await uploadReceiptUseCase(file, expenseId);
  }

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
    _categories = [category, ..._categories];
    notifyListeners();

    try {
      await insertExpenseCategoryUseCase(category);
    } catch (e) {
      _categories = _categories.where((c) => c.id != category.id).toList();
      _error = e.toString();
      debugPrint('Error inserting category: $e');
      notifyListeners();
    }
  }

  Future<void> updateCategory(ExpenseCategoryEntity category) async {
    _error = null;
    final index = _categories.indexWhere((c) => c.id == category.id);
    ExpenseCategoryEntity? oldCategory;

    if (index != -1) {
      oldCategory = _categories[index];
      _categories[index] = category;
      notifyListeners();
    }

    try {
      await updateExpenseCategoryUseCase(category);
    } catch (e) {
      if (index != -1 && oldCategory != null) {
        _categories[index] = oldCategory;
      }
      _error = e.toString();
      debugPrint('Error updating category: $e');
      notifyListeners();
    }
  }

  Future<void> deleteCategory(String id) async {
    _error = null;
    final index = _categories.indexWhere((c) => c.id == id);
    ExpenseCategoryEntity? oldCategory;

    if (index != -1) {
      oldCategory = _categories[index];
      _categories.removeAt(index);
      notifyListeners();
    }

    try {
      await deleteExpenseCategoryUseCase(id);
    } catch (e) {
      if (index != -1 && oldCategory != null) {
        _categories.insert(index, oldCategory);
      }
      _error = e.toString();
      debugPrint('Error deleting category: $e');
      notifyListeners();
    }
  }

  List<ExpenseTypeEntity> getTypesForCategory(String categoryName) {
    final index = _categories.indexWhere((c) => c.name == categoryName);
    if (index == -1) return [];
    return _categories[index].expenseTypes.where((t) => t.isActive).toList();
  }
}
