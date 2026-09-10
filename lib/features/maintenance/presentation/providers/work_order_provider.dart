import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xloop_invoice/features/auth/domain/entities/user_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/finance_policy_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';

import '../../domain/entities/work_order_entity.dart';
import '../../domain/entities/work_order_line.dart';
import '../../domain/entities/work_order_status.dart';
import '../../domain/repositories/work_order_repository.dart';
import '../../domain/services/work_order_transition_service.dart';
import '../../domain/usecases/close_work_order_usecase.dart';
import '../../domain/usecases/create_work_order_usecase.dart';
import '../../domain/usecases/get_work_orders_usecase.dart';
import '../../domain/usecases/work_order_workflow_usecases.dart';

/// State for the maintenance work order module.
class WorkOrderProvider with ChangeNotifier {
  final GetWorkOrdersUseCase getWorkOrdersUseCase;
  final GetWorkOrdersForVehicleUseCase getWorkOrdersForVehicleUseCase;
  final GetOpenWorkOrdersUseCase getOpenWorkOrdersUseCase;
  final GetWorkOrderByIdUseCase getWorkOrderByIdUseCase;
  final CreateWorkOrderUseCase createWorkOrderUseCase;
  final UpdateWorkOrderUseCase updateWorkOrderUseCase;
  final IssueWorkOrderUseCase issueWorkOrderUseCase;
  final ApproveWorkOrderUseCase approveWorkOrderUseCase;
  final RejectWorkOrderUseCase rejectWorkOrderUseCase;
  final StartWorkOrderUseCase startWorkOrderUseCase;
  final HoldWorkOrderUseCase holdWorkOrderUseCase;
  final ResumeWorkOrderUseCase resumeWorkOrderUseCase;
  final CompleteWorkOrderUseCase completeWorkOrderUseCase;
  final CancelWorkOrderUseCase cancelWorkOrderUseCase;
  final CloseWorkOrderUseCase closeWorkOrderUseCase;
  final WorkOrderTransitionService transitions;
  final WorkOrderRepository repository;

  WorkOrderProvider({
    required this.getWorkOrdersUseCase,
    required this.getWorkOrdersForVehicleUseCase,
    required this.getOpenWorkOrdersUseCase,
    required this.getWorkOrderByIdUseCase,
    required this.createWorkOrderUseCase,
    required this.updateWorkOrderUseCase,
    required this.issueWorkOrderUseCase,
    required this.approveWorkOrderUseCase,
    required this.rejectWorkOrderUseCase,
    required this.startWorkOrderUseCase,
    required this.holdWorkOrderUseCase,
    required this.resumeWorkOrderUseCase,
    required this.completeWorkOrderUseCase,
    required this.cancelWorkOrderUseCase,
    required this.closeWorkOrderUseCase,
    required this.transitions,
    required this.repository,
  });

  List<WorkOrderEntity> _workOrders = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;

  // Filters
  WorkOrderStatus? _statusFilter;
  String? _vehicleFilter;
  String? _shopFilter;
  String _searchQuery = '';
  bool _mineOnly = false;
  bool _showClosed = false;

  List<WorkOrderEntity> get workOrders => _workOrders;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  WorkOrderStatus? get statusFilter => _statusFilter;
  String? get vehicleFilter => _vehicleFilter;
  String? get shopFilter => _shopFilter;
  String get searchQuery => _searchQuery;
  bool get mineOnly => _mineOnly;
  bool get showClosed => _showClosed;

  /// Live work orders keyed by vehicle id — used to suppress maintenance
  /// alerts for a vehicle that is already booked in.
  Map<String, List<WorkOrderEntity>> get openByVehicle {
    final map = <String, List<WorkOrderEntity>>{};
    for (final wo in _workOrders.where((w) => w.isOpen)) {
      map.putIfAbsent(wo.vehicleId, () => []).add(wo);
    }
    return map;
  }

  /// The open work order covering [maintenanceTypeId] on [vehicleId], if any.
  ///
  /// This is what lets an alert say "WO-2026-0014 · In Progress" instead of
  /// nagging about a service that is already booked in.
  WorkOrderEntity? openWorkOrderFor({
    required String vehicleId,
    String? maintenanceTypeId,
    String? maintenanceTypeName,
  }) {
    for (final wo in _workOrders) {
      if (!wo.isOpen || wo.vehicleId != vehicleId) continue;
      if (maintenanceTypeId == null && maintenanceTypeName == null) return wo;
      if (wo.sourceAlertTypeId != null &&
          wo.sourceAlertTypeId == maintenanceTypeId) {
        return wo;
      }
      for (final line in wo.lines) {
        if (maintenanceTypeId != null &&
            line.maintenanceTypeId == maintenanceTypeId) {
          return wo;
        }
        if (maintenanceTypeName != null &&
            line.effectiveTypeName.toLowerCase().trim() ==
                maintenanceTypeName.toLowerCase().trim()) {
          return wo;
        }
      }
    }
    return null;
  }

  /// Vehicles currently at the workshop, by id.
  Set<String> get vehicleIdsInShop => _workOrders
      .where((w) => w.occupiesVehicle)
      .map((w) => w.vehicleId)
      .toSet();

  List<WorkOrderEntity> get filteredWorkOrders {
    var result = List<WorkOrderEntity>.from(_workOrders);

    if (!_showClosed) {
      result = result.where((w) => !w.status.isTerminal).toList();
    }
    if (_statusFilter != null) {
      result = result.where((w) => w.status == _statusFilter).toList();
    }
    if (_vehicleFilter != null && _vehicleFilter!.isNotEmpty) {
      result = result.where((w) => w.vehicleId == _vehicleFilter).toList();
    }
    if (_shopFilter != null && _shopFilter!.isNotEmpty) {
      result = result.where((w) => w.shopId == _shopFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((w) {
        return w.workOrderNumber.toLowerCase().contains(q) ||
            w.vehiclePlate.toLowerCase().contains(q) ||
            (w.vehicleName?.toLowerCase().contains(q) ?? false) ||
            w.complaint.toLowerCase().contains(q) ||
            (w.shopName?.toLowerCase().contains(q) ?? false) ||
            w.lineSummary.toLowerCase().contains(q);
      }).toList();
    }

    result.sort((a, b) {
      // Urgent first, then oldest — the queue you should work top-down.
      final byPriority = b.priority.weight.compareTo(a.priority.weight);
      if (byPriority != 0) return byPriority;
      return a.createdAt.compareTo(b.createdAt);
    });
    return result;
  }

  /// Work orders split into board lanes for [user].
  Map<WorkOrderLane, List<WorkOrderEntity>> lanesFor({
    required UserEntity? user,
    required FinancePolicyEntity policy,
  }) {
    final lanes = <WorkOrderLane, List<WorkOrderEntity>>{
      WorkOrderLane.needsAction: [],
      WorkOrderLane.inProgress: [],
      WorkOrderLane.done: [],
    };
    for (final wo in filteredWorkOrders) {
      if (_mineOnly && !_isMine(wo, user)) continue;
      final lane = transitions.laneFor(
        workOrder: wo,
        user: user,
        policy: policy,
      );
      lanes[lane]!.add(wo);
    }
    return lanes;
  }

  /// Count of work orders waiting on [user] — drives the nav badge.
  int needsActionCount({
    required UserEntity? user,
    required FinancePolicyEntity policy,
  }) {
    return _workOrders
        .where(
          (w) => transitions.needsActionFrom(
            workOrder: w,
            user: user,
            policy: policy,
          ),
        )
        .length;
  }

  bool _isMine(WorkOrderEntity wo, UserEntity? user) {
    if (user == null) return false;
    return wo.createdByUserId == user.id || wo.reportedByUserId == user.id;
  }

  // ─── Filters ─────────────────────────────────────────────────

  void setStatusFilter(WorkOrderStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setVehicleFilter(String? vehicleId) {
    _vehicleFilter = vehicleId;
    notifyListeners();
  }

  void setShopFilter(String? shopId) {
    _shopFilter = shopId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void setMineOnly(bool value) {
    _mineOnly = value;
    notifyListeners();
  }

  void setShowClosed(bool value) {
    _showClosed = value;
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = null;
    _vehicleFilter = null;
    _shopFilter = null;
    _searchQuery = '';
    _mineOnly = false;
    _showClosed = false;
    notifyListeners();
  }

  // ─── Loading ─────────────────────────────────────────────────

  Future<void> fetchWorkOrders({bool force = false}) async {
    if (_isLoading) return;
    if (_workOrders.isNotEmpty && !force) return;
    _setLoading(true);
    try {
      _workOrders = await getWorkOrdersUseCase();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<List<WorkOrderEntity>> fetchForVehicle(String vehicleId) async {
    try {
      return await getWorkOrdersForVehicleUseCase(vehicleId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return const [];
    }
  }

  Future<WorkOrderEntity?> refreshOne(String id) async {
    final fresh = await getWorkOrderByIdUseCase(id);
    if (fresh != null) _replace(fresh);
    return fresh;
  }

  // ─── Mutations ───────────────────────────────────────────────

  /// Runs [action], keeping the local list and error state in sync.
  ///
  /// Returns null and sets [error] when the action was rejected — every
  /// use case throws [StateError] with a message meant for the user.
  Future<T?> _run<T>(Future<T> Function() action) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();
    try {
      return await action();
    } catch (e) {
      _error = e is StateError ? e.message : e.toString();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<WorkOrderEntity?> createWorkOrder({
    required VehicleEntity vehicle,
    required String complaint,
    required UserEntity actor,
    required FinancePolicyEntity policy,
    WorkOrderSource source = WorkOrderSource.adhoc,
    WorkOrderPriority priority = WorkOrderPriority.normal,
    List<WorkOrderLine> lines = const [],
    String? shopId,
    String? shopName,
    DateTime? scheduledDate,
    int? odometerAtRequest,
    List<String> reportedAttachmentUrls = const [],
    String? sourceAlertTypeId,
    String? fundAccountId,
    String? fundAccountName,
    String paymentMethod = 'cash',
    String? notes,
  }) {
    return _run(() async {
      final created = await createWorkOrderUseCase(
        vehicle: vehicle,
        complaint: complaint,
        actor: actor,
        policy: policy,
        source: source,
        priority: priority,
        lines: lines,
        shopId: shopId,
        shopName: shopName,
        scheduledDate: scheduledDate,
        odometerAtRequest: odometerAtRequest,
        reportedAttachmentUrls: reportedAttachmentUrls,
        sourceAlertTypeId: sourceAlertTypeId,
        fundAccountId: fundAccountId,
        fundAccountName: fundAccountName,
        paymentMethod: paymentMethod,
        notes: notes,
      );
      _workOrders = [created, ..._workOrders];
      return created;
    });
  }

  Future<WorkOrderEntity?> saveDetails({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    String? note,
  }) {
    return _run(() async {
      final updated = await updateWorkOrderUseCase(
        workOrder: workOrder,
        actor: actor,
        note: note,
      );
      _replace(updated);
      return updated;
    });
  }

  Future<WorkOrderEntity?> issue({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
  }) =>
      _run(() async {
        final r = await issueWorkOrderUseCase(
          workOrder: workOrder,
          actor: actor,
          policy: policy,
        );
        _replace(r);
        return r;
      });

  Future<WorkOrderEntity?> approve({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
    String? note,
  }) =>
      _run(() async {
        final r = await approveWorkOrderUseCase(
          workOrder: workOrder,
          actor: actor,
          policy: policy,
          note: note,
        );
        _replace(r);
        return r;
      });

  Future<WorkOrderEntity?> reject({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
    required String reason,
  }) =>
      _run(() async {
        final r = await rejectWorkOrderUseCase(
          workOrder: workOrder,
          actor: actor,
          policy: policy,
          reason: reason,
        );
        _replace(r);
        return r;
      });

  Future<WorkOrderEntity?> start({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
    int? odometerAtService,
  }) =>
      _run(() async {
        final r = await startWorkOrderUseCase(
          workOrder: workOrder,
          actor: actor,
          policy: policy,
          odometerAtService: odometerAtService,
        );
        _replace(r);
        return r;
      });

  Future<WorkOrderEntity?> hold({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
    required String reason,
  }) =>
      _run(() async {
        final r = await holdWorkOrderUseCase(
          workOrder: workOrder,
          actor: actor,
          policy: policy,
          reason: reason,
        );
        _replace(r);
        return r;
      });

  Future<WorkOrderEntity?> resume({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
  }) =>
      _run(() async {
        final r = await resumeWorkOrderUseCase(
          workOrder: workOrder,
          actor: actor,
          policy: policy,
        );
        _replace(r);
        return r;
      });

  Future<WorkOrderEntity?> complete({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
  }) =>
      _run(() async {
        final r = await completeWorkOrderUseCase(
          workOrder: workOrder,
          actor: actor,
          policy: policy,
        );
        _replace(r);
        return r;
      });

  Future<WorkOrderEntity?> cancel({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
    required String reason,
  }) =>
      _run(() async {
        final r = await cancelWorkOrderUseCase(
          workOrder: workOrder,
          actor: actor,
          policy: policy,
          reason: reason,
        );
        _replace(r);
        return r;
      });

  Future<CloseWorkOrderResult?> close({
    required WorkOrderEntity workOrder,
    required UserEntity actor,
    required FinancePolicyEntity policy,
  }) =>
      _run(() async {
        final result = await closeWorkOrderUseCase(
          workOrder: workOrder,
          actor: actor,
          policy: policy,
        );
        _replace(result.workOrder);
        return result;
      });

  Future<String?> uploadAttachment({
    required XFile file,
    required String workOrderId,
    required String kind,
  }) =>
      _run(() => repository.uploadAttachment(file, workOrderId, kind));

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void _replace(WorkOrderEntity workOrder) {
    final index = _workOrders.indexWhere((w) => w.id == workOrder.id);
    if (index >= 0) {
      _workOrders[index] = workOrder;
    } else {
      _workOrders = [workOrder, ..._workOrders];
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
