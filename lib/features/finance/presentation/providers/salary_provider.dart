import 'package:flutter/foundation.dart';
import '../../domain/entities/salary_entity.dart';
import '../../domain/usecases/salary_usecases.dart';

/// Payroll state: who is on the payroll and what each month has been paid.
///
/// The provider always holds one selected month ([period]) and the salary rows
/// belonging to it.
class SalaryProvider with ChangeNotifier {
  final GetSalaryStructuresUseCase getSalaryStructuresUseCase;
  final SaveSalaryStructureUseCase saveSalaryStructureUseCase;
  final DeleteSalaryStructureUseCase deleteSalaryStructureUseCase;
  final GetSalaryPaymentsUseCase getSalaryPaymentsUseCase;
  final GenerateSalaryRunUseCase generateSalaryRunUseCase;
  final SaveSalaryPaymentUseCase saveSalaryPaymentUseCase;
  final PaySalaryUseCase paySalaryUseCase;
  final DeleteSalaryPaymentUseCase deleteSalaryPaymentUseCase;
  final VoidSalaryPaymentUseCase voidSalaryPaymentUseCase;

  SalaryProvider({
    required this.getSalaryStructuresUseCase,
    required this.saveSalaryStructureUseCase,
    required this.deleteSalaryStructureUseCase,
    required this.getSalaryPaymentsUseCase,
    required this.generateSalaryRunUseCase,
    required this.saveSalaryPaymentUseCase,
    required this.paySalaryUseCase,
    required this.deleteSalaryPaymentUseCase,
    required this.voidSalaryPaymentUseCase,
  });

  List<SalaryStructureEntity> _structures = [];
  List<SalaryPaymentEntity> _payments = [];
  String _period = SalaryPaymentEntity.periodOf(DateTime.now());
  bool _isLoading = false;
  String? _error;

  List<SalaryStructureEntity> get structures => _structures;
  List<SalaryStructureEntity> get activeStructures =>
      _structures.where((s) => s.isActive).toList();

  /// Salary rows of the selected [period].
  List<SalaryPaymentEntity> get payments => _payments;
  String get period => _period;
  bool get isLoading => _isLoading;
  String? get error => _error;

  DateTime get periodDate {
    final parts = _period.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  List<SalaryPaymentEntity> get pendingPayments =>
      _payments.where((p) => p.status == SalaryPaymentStatus.pending).toList();
  List<SalaryPaymentEntity> get paidPayments =>
      _payments.where((p) => p.status == SalaryPaymentStatus.paid).toList();

  /// Net total of everything still to be paid this month.
  double get totalPending =>
      pendingPayments.fold(0.0, (sum, p) => sum + p.netAmount);

  /// Net total already posted to fund accounts this month.
  double get totalPaid => paidPayments.fold(0.0, (sum, p) => sum + p.netAmount);

  /// Monthly payroll cost of everyone on the payroll (before deductions).
  double get monthlyPayrollCost =>
      activeStructures.fold(0.0, (sum, s) => sum + s.grossSalary);

  SalaryStructureEntity? structureFor(String employeeId) {
    for (final s in _structures) {
      if (s.employeeId == employeeId) return s;
    }
    return null;
  }

  SalaryPaymentEntity? paymentFor(String employeeId) {
    for (final p in _payments) {
      if (p.employeeId == employeeId) return p;
    }
    return null;
  }

  Future<void> load({String? period}) async {
    _isLoading = true;
    _error = null;
    if (period != null && period.isNotEmpty) _period = period;
    notifyListeners();
    try {
      final results = await Future.wait([
        getSalaryStructuresUseCase(),
        getSalaryPaymentsUseCase(period: _period),
      ]);
      _structures = results[0] as List<SalaryStructureEntity>;
      _payments = results[1] as List<SalaryPaymentEntity>;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading salaries: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Moves the selected month by [months] (negative goes back) and reloads.
  Future<void> shiftPeriod(int months) async {
    final current = periodDate;
    final next = DateTime(current.year, current.month + months);
    await load(period: SalaryPaymentEntity.periodOf(next));
  }

  Future<void> saveStructure(SalaryStructureEntity structure) async {
    _error = null;
    try {
      final saved = await saveSalaryStructureUseCase(structure);
      final i =
          _structures.indexWhere((s) => s.employeeId == saved.employeeId);
      if (i == -1) {
        _structures = [..._structures, saved]
          ..sort((a, b) => a.employeeName.compareTo(b.employeeName));
      } else {
        _structures[i] = saved;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeStructure(String employeeId) async {
    _error = null;
    try {
      await deleteSalaryStructureUseCase(employeeId);
      _structures =
          _structures.where((s) => s.employeeId != employeeId).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Creates the missing pending rows for the selected month.
  Future<int> generateRun({
    required String actorName,
    String? actorUserId,
  }) async {
    _error = null;
    final before = _payments.length;
    try {
      _payments = await generateSalaryRunUseCase(
        period: _period,
        actorName: actorName,
        actorUserId: actorUserId,
      );
      notifyListeners();
      return _payments.length - before;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> savePayment(SalaryPaymentEntity payment) async {
    _error = null;
    try {
      final saved = await saveSalaryPaymentUseCase(payment);
      _upsert(saved);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pay({
    required String paymentId,
    required String fundAccountId,
    required String actorName,
    String? actorUserId,
  }) async {
    _error = null;
    try {
      final updated = await paySalaryUseCase(
        paymentId: paymentId,
        fundAccountId: fundAccountId,
        actorName: actorName,
        actorUserId: actorUserId,
      );
      _upsert(updated);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deletePayment(String paymentId) async {
    _error = null;
    try {
      await deleteSalaryPaymentUseCase(paymentId);
      _payments = _payments.where((p) => p.id != paymentId).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> voidPayment({
    required String paymentId,
    required String reason,
    required String actorName,
    String? actorUserId,
  }) async {
    _error = null;
    try {
      final updated = await voidSalaryPaymentUseCase(
        paymentId: paymentId,
        reason: reason,
        actorName: actorName,
        actorUserId: actorUserId,
      );
      _upsert(updated);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void _upsert(SalaryPaymentEntity payment) {
    if (payment.period != _period) return;
    final i = _payments.indexWhere((p) => p.id == payment.id);
    if (i == -1) {
      _payments = [..._payments, payment]
        ..sort((a, b) => a.employeeName.compareTo(b.employeeName));
    } else {
      _payments[i] = payment;
    }
  }
}
