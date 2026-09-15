import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xloop_invoice/features/finance/domain/entities/expense_category_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/expense_entity.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/approve_expense_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/delete_expense_category_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/delete_expense_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/generate_reference_number_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/get_all_expenses_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/get_expense_categories_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/get_expenses_by_account_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/get_expenses_by_date_range_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/insert_expense_category_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/insert_expense_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/reject_expense_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/update_expense_category_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/update_expense_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/upload_receipt_usecase.dart';
import 'package:xloop_invoice/features/finance/domain/usecases/void_expense_usecase.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/finance_provider.dart';

import '../../domain/usecases/test_finance_repository.dart';

class FilterTestFinanceRepository extends FakeFinanceRepository {
  List<ExpenseEntity> pageExpenses = [];
  List<ExpenseCategoryEntity> repoCategories = [];

  @override
  Future<(List<ExpenseEntity>, DocumentSnapshot?)> getExpensesPage({
    DocumentSnapshot? cursor,
    int pageSize = 150,
  }) async {
    return (pageExpenses, null);
  }

  @override
  Future<List<ExpenseCategoryEntity>> getExpenseCategories() async {
    return repoCategories;
  }
}

void main() {
  late FilterTestFinanceRepository repo;
  late FinanceProvider provider;

  final catVehicles = ExpenseCategoryEntity(
    id: 'cat-1',
    name: 'VEHICLES',
    createdAt: DateTime(2025, 1, 1),
    expenseTypes: const [
      ExpenseTypeEntity(
        id: 't-1',
        name: 'Fuel',
        defaultDuration: 'DAILY',
        submittedByRole: 'DRIVER',
        isActive: true,
      ),
      ExpenseTypeEntity(
        id: 't-2',
        name: 'Car Wash',
        defaultDuration: 'WEEKLY',
        submittedByRole: 'DRIVER',
        isActive: true,
      ),
    ],
  );

  final catOffice = ExpenseCategoryEntity(
    id: 'cat-2',
    name: 'OFFICE',
    createdAt: DateTime(2025, 1, 1),
    expenseTypes: const [
      ExpenseTypeEntity(
        id: 't-3',
        name: 'Stationery',
        defaultDuration: 'MONTHLY',
        submittedByRole: 'ADMIN',
        isActive: true,
      ),
    ],
  );

  final sampleExpenses = [
    ExpenseEntity(
      id: 'e-1',
      referenceNumber: '#1001',
      date: DateTime(2025, 1, 1),
      createdAt: DateTime(2025, 1, 1),
      submittedBy: 'Driver 1',
      submittedByRole: 'driver',
      expenseCategory: 'VEHICLES',
      expenseType: 'Fuel',
      paymentMethod: 'cash',
      amount: 150,
      currency: 'SAR',
      fundAccountId: 'acc-1',
      status: ExpenseStatus.paid,
    ),
    ExpenseEntity(
      id: 'e-2',
      referenceNumber: '#1002',
      date: DateTime(2025, 1, 2),
      createdAt: DateTime(2025, 1, 2),
      submittedBy: 'Driver 2',
      submittedByRole: 'driver',
      expenseCategory: 'VEHICLES',
      expenseType: 'Car Wash',
      paymentMethod: 'cash',
      amount: 40,
      currency: 'SAR',
      fundAccountId: 'acc-1',
      status: ExpenseStatus.pending,
    ),
    ExpenseEntity(
      id: 'e-3',
      referenceNumber: '#1003',
      date: DateTime(2025, 1, 3),
      createdAt: DateTime(2025, 1, 3),
      submittedBy: 'Admin',
      submittedByRole: 'admin',
      expenseCategory: 'OFFICE',
      expenseType: 'Stationery',
      paymentMethod: 'cash',
      amount: 80,
      currency: 'SAR',
      fundAccountId: 'acc-2',
      status: ExpenseStatus.paid,
    ),
  ];

  setUp(() async {
    repo = FilterTestFinanceRepository();
    repo.pageExpenses = List.from(sampleExpenses);
    repo.repoCategories = [catVehicles, catOffice];

    provider = FinanceProvider(
      getAllExpensesUseCase: GetAllExpensesUseCase(repo),
      getExpensesByDateRangeUseCase: GetExpensesByDateRangeUseCase(repo),
      getExpensesByAccountUseCase: GetExpensesByAccountUseCase(repo),
      insertExpenseUseCase: InsertExpenseUseCase(repo),
      updateExpenseUseCase: UpdateExpenseUseCase(repo),
      deleteExpenseUseCase: DeleteExpenseUseCase(repo),
      approveExpenseUseCase: ApproveExpenseUseCase(repo),
      rejectExpenseUseCase: RejectExpenseUseCase(repo),
      voidExpenseUseCase: VoidExpenseUseCase(repo),
      generateReferenceNumberUseCase: GenerateReferenceNumberUseCase(repo),
      uploadReceiptUseCase: UploadReceiptUseCase(repo),
      getExpenseCategoriesUseCase: GetExpenseCategoriesUseCase(repo),
      insertExpenseCategoryUseCase: InsertExpenseCategoryUseCase(repo),
      updateExpenseCategoryUseCase: UpdateExpenseCategoryUseCase(repo),
      deleteExpenseCategoryUseCase: DeleteExpenseCategoryUseCase(repo),
      financeRepository: repo,
    );

    await provider.fetchAllExpenses();
    await provider.fetchCategories();
  });

  group('Expense Type Filter Tests', () {
    test('setTypeFilter updates filter and notifies listeners', () {
      bool notified = false;
      provider.addListener(() => notified = true);

      provider.setTypeFilter('Fuel');

      expect(provider.typeFilter, equals('Fuel'));
      expect(notified, isTrue);
    });

    test('filteredExpenses filters by expenseType case-insensitively', () {
      provider.setTypeFilter('fuel');
      expect(provider.filteredExpenses.length, equals(1));
      expect(provider.filteredExpenses.first.id, equals('e-1'));

      provider.setTypeFilter('Car Wash');
      expect(provider.filteredExpenses.length, equals(1));
      expect(provider.filteredExpenses.first.id, equals('e-2'));
    });

    test('filteredExpenses combines category and type filters', () {
      provider.setCategoryFilter('VEHICLES');
      provider.setTypeFilter('Fuel');
      expect(provider.filteredExpenses.length, equals(1));
      expect(provider.filteredExpenses.first.id, equals('e-1'));

      // If category has no match for Stationery
      provider.setCategoryFilter('OFFICE');
      // Stationery is in OFFICE
      provider.setTypeFilter('Stationery');
      expect(provider.filteredExpenses.length, equals(1));
      expect(provider.filteredExpenses.first.id, equals('e-3'));
    });

    test('clearFilters clears typeFilter along with other filters', () {
      provider.setCategoryFilter('VEHICLES');
      provider.setTypeFilter('Fuel');
      provider.setStatusFilter(ExpenseStatus.paid);

      provider.clearFilters();

      expect(provider.typeFilter, isNull);
      expect(provider.categoryFilter, isNull);
      expect(provider.statusFilter, isNull);
      expect(provider.filteredExpenses.length, equals(3));
    });

    test('setCategoryFilter clears incompatible typeFilter', () {
      provider.setCategoryFilter('VEHICLES');
      provider.setTypeFilter('Fuel');
      expect(provider.typeFilter, equals('Fuel'));

      // Switching to OFFICE should clear Fuel because Fuel is not in OFFICE
      provider.setCategoryFilter('OFFICE');
      expect(provider.typeFilter, isNull);
    });

    test('availableExpenseTypes lists all types when no category selected', () {
      final types = provider.availableExpenseTypes;
      expect(types, contains('Fuel'));
      expect(types, contains('Car Wash'));
      expect(types, contains('Stationery'));
    });

    test('availableExpenseTypes filters types when category selected', () {
      provider.setCategoryFilter('VEHICLES');
      final types = provider.availableExpenseTypes;
      expect(types, contains('Fuel'));
      expect(types, contains('Car Wash'));
      expect(types.contains('Stationery'), isFalse);
    });
  });
}
