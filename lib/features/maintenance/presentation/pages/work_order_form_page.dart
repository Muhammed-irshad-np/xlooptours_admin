import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:xloop_invoice/core/utils/app_snack_bar.dart';
import 'package:xloop_invoice/core/widgets/modern_app_bar.dart';
import 'package:xloop_invoice/features/auth/presentation/providers/auth_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/finance_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/fund_account_provider.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/maintenance_type_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/services/maintenance_history_writer.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';

import '../../domain/entities/work_order_entity.dart';
import '../../domain/entities/work_order_line.dart';
import '../../domain/entities/work_order_status.dart';
import '../providers/work_order_provider.dart';

/// Editable state for one work order line.
class _LineDraft {
  String id;
  String? maintenanceTypeId;
  final TextEditingController customName = TextEditingController();
  final TextEditingController estimate = TextEditingController();
  final TextEditingController actual = TextEditingController();
  final TextEditingController parts = TextEditingController();
  final TextEditingController notes = TextEditingController();
  bool completed = true;

  _LineDraft({String? id}) : id = id ?? const Uuid().v4();

  _LineDraft.fromLine(WorkOrderLine line) : id = line.id {
    maintenanceTypeId = line.maintenanceTypeId;
    customName.text = line.customTypeName ?? '';
    estimate.text = line.estimatedCost == 0
        ? ''
        : line.estimatedCost.toStringAsFixed(2);
    actual.text = line.actualCost?.toStringAsFixed(2) ?? '';
    parts.text = line.partsReplaced ?? '';
    notes.text = line.notes ?? '';
    completed = line.completed;
  }

  void dispose() {
    customName.dispose();
    estimate.dispose();
    actual.dispose();
    parts.dispose();
    notes.dispose();
  }
}

/// Create a new work order, or edit an existing one's details.
///
/// When [initialVehicle] and [initialMaintenanceTypeId] are supplied the form
/// arrives pre-filled — that is the one-tap path from a maintenance alert,
/// which is the highest-volume way work orders get created.
class WorkOrderFormPage extends StatefulWidget {
  /// Existing work order to edit. Null creates a new one.
  final WorkOrderEntity? workOrder;

  final VehicleEntity? initialVehicle;
  final String? initialMaintenanceTypeId;
  final String? initialComplaint;

  const WorkOrderFormPage({
    super.key,
    this.workOrder,
    this.initialVehicle,
    this.initialMaintenanceTypeId,
    this.initialComplaint,
  });

  @override
  State<WorkOrderFormPage> createState() => _WorkOrderFormPageState();
}

class _WorkOrderFormPageState extends State<WorkOrderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _complaint = TextEditingController();
  final _notes = TextEditingController();
  final _odometer = TextEditingController();
  final _invoiceNumber = TextEditingController();

  VehicleEntity? _vehicle;
  String? _shopId;
  String? _shopName;
  DateTime? _scheduledDate;
  WorkOrderPriority _priority = WorkOrderPriority.normal;
  String? _fundAccountId;
  String? _fundAccountName;
  String _paymentMethod = 'cash';
  final List<_LineDraft> _lines = [];

  bool get _isEdit => widget.workOrder != null;

  /// Actual costs are only meaningful once the job is under way.
  bool get _showActuals {
    final status = widget.workOrder?.status;
    return status == WorkOrderStatus.inProgress ||
        status == WorkOrderStatus.onHold ||
        status == WorkOrderStatus.completed;
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.workOrder;
    if (existing != null) {
      _complaint.text = existing.complaint;
      _notes.text = existing.notes ?? '';
      _odometer.text = existing.odometerAtService?.toString() ??
          existing.odometerAtRequest?.toString() ??
          '';
      _invoiceNumber.text = existing.shopInvoiceNumber ?? '';
      _shopId = existing.shopId;
      _shopName = existing.shopName;
      _scheduledDate = existing.scheduledDate;
      _priority = existing.priority;
      _fundAccountId = existing.fundAccountId;
      _fundAccountName = existing.fundAccountName;
      _paymentMethod = existing.paymentMethod;
      _lines.addAll(existing.lines.map(_LineDraft.fromLine));
    } else {
      _complaint.text = widget.initialComplaint ?? '';
      _lines.add(
        _LineDraft()..maintenanceTypeId = widget.initialMaintenanceTypeId,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final vehicleProvider = context.read<VehicleProvider>();
      final fundProvider = context.read<FundAccountProvider>();
      await Future.wait<dynamic>([
        if (vehicleProvider.vehicles.isEmpty)
          vehicleProvider.fetchAllVehicles(),
        if (vehicleProvider.maintenanceTypes.isEmpty)
          vehicleProvider.fetchAllMaintenanceTypes(),
        if (vehicleProvider.shops.isEmpty) vehicleProvider.fetchAllShops(),
        if (fundProvider.accounts.isEmpty) fundProvider.fetchAllAccounts(),
      ]);
      if (!mounted) return;
      setState(() {
        _vehicle = widget.initialVehicle ??
            _findVehicle(vehicleProvider, widget.workOrder?.vehicleId);
        if (_odometer.text.isEmpty && _vehicle?.currentOdometer != null) {
          _odometer.text = _vehicle!.currentOdometer.toString();
        }
      });
    });
  }

  VehicleEntity? _findVehicle(VehicleProvider provider, String? id) {
    if (id == null) return null;
    for (final v in provider.vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  @override
  void dispose() {
    _complaint.dispose();
    _notes.dispose();
    _odometer.dispose();
    _invoiceNumber.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _estimatedTotal => _lines.fold(
        0.0,
        (sum, l) => sum + (double.tryParse(l.estimate.text.trim()) ?? 0),
      );

  double get _actualTotal => _lines.where((l) => l.completed).fold(
        0.0,
        (sum, l) =>
            sum +
            (double.tryParse(l.actual.text.trim()) ??
                double.tryParse(l.estimate.text.trim()) ??
                0),
      );

  @override
  Widget build(BuildContext context) {
    final policy = context.watch<FinanceProvider>().policy;
    final autoApproves = !_isEdit &&
        _lines.isNotEmpty &&
        policy.workOrderSkipsApproval(_estimatedTotal) &&
        _estimatedTotal > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: ModernAppBar(
        title: _isEdit
            ? 'Edit ${widget.workOrder!.workOrderNumber}'
            : 'New Work Order',
      ),
      bottomNavigationBar: _buildBottomBar(autoApproves),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
          children: [
            _section(
              'Vehicle & problem',
              [
                _buildVehiclePicker(),
                SizedBox(height: 12.h),
                TextFormField(
                  controller: _complaint,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    'What is wrong? *',
                    hint: 'e.g. Grinding noise from front brakes',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Describe the problem'
                      : null,
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(child: _buildPriorityPicker()),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: TextFormField(
                        controller: _odometer,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: _inputDecoration('Odometer (km)'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _section('Work to be done', [_buildLinesEditor()]),
            SizedBox(height: 16.h),
            _section(
              'Workshop & schedule',
              [
                _buildShopPicker(),
                SizedBox(height: 12.h),
                _buildScheduledDate(),
                if (_showActuals) ...[
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: _invoiceNumber,
                    decoration: _inputDecoration('Shop invoice number'),
                  ),
                ],
              ],
            ),
            SizedBox(height: 16.h),
            _section(
              'Payment',
              [
                _buildWalletPicker(),
                SizedBox(height: 12.h),
                _buildPaymentMethodPicker(),
                SizedBox(height: 8.h),
                Text(
                  'The wallet is only charged when the work order is closed. '
                  'Nothing moves before then.',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _section(
              'Notes',
              [
                TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _inputDecoration('Internal notes (optional)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sections ────────────────────────────────────────────────

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          SizedBox(height: 12.h),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.inter(fontSize: 13.sp),
      hintStyle: GoogleFonts.inter(
        fontSize: 12.sp,
        color: const Color(0xFF9CA3AF),
      ),
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
    );
  }

  Widget _buildVehiclePicker() {
    final vehicles = context.watch<VehicleProvider>().vehicles;
    return DropdownButtonFormField<String>(
      initialValue: _vehicle?.id,
      isExpanded: true,
      decoration: _inputDecoration('Vehicle *'),
      items: vehicles
          .map(
            (v) => DropdownMenuItem(
              value: v.id,
              child: Text(
                '${v.plateNumber} · ${v.make} ${v.model}',
                style: GoogleFonts.inter(fontSize: 13.sp),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      validator: (v) => v == null ? 'Pick a vehicle' : null,
      // Editing keeps the subject fixed: moving a work order to another
      // vehicle would orphan its history write-back.
      onChanged: _isEdit
          ? null
          : (id) {
              setState(() {
                _vehicle = vehicles.where((v) => v.id == id).firstOrNull;
                if (_vehicle?.currentOdometer != null) {
                  _odometer.text = _vehicle!.currentOdometer.toString();
                }
              });
            },
    );
  }

  Widget _buildPriorityPicker() {
    return DropdownButtonFormField<WorkOrderPriority>(
      initialValue: _priority,
      isExpanded: true,
      decoration: _inputDecoration('Priority'),
      items: WorkOrderPriority.values
          .map(
            (p) => DropdownMenuItem(
              value: p,
              child: Text(
                p.displayName,
                style: GoogleFonts.inter(fontSize: 13.sp),
              ),
            ),
          )
          .toList(),
      onChanged: (p) => setState(() => _priority = p ?? _priority),
    );
  }

  Widget _buildShopPicker() {
    final shops = context.watch<VehicleProvider>().shops;
    return DropdownButtonFormField<String>(
      initialValue: shops.any((s) => s.id == _shopId) ? _shopId : null,
      isExpanded: true,
      decoration: _inputDecoration('Workshop'),
      items: shops
          .map(
            (s) => DropdownMenuItem(
              value: s.id,
              child: Text(
                s.name,
                style: GoogleFonts.inter(fontSize: 13.sp),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (id) {
        final shop = shops.where((s) => s.id == id).firstOrNull;
        setState(() {
          _shopId = shop?.id;
          _shopName = shop?.name;
        });
      },
    );
  }

  Widget _buildScheduledDate() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _scheduledDate ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) setState(() => _scheduledDate = picked);
      },
      child: InputDecorator(
        decoration: _inputDecoration('Scheduled date'),
        child: Text(
          _scheduledDate == null
              ? 'Not scheduled'
              : DateFormat('MMM dd, yyyy').format(_scheduledDate!),
          style: GoogleFonts.inter(
            fontSize: 13.sp,
            color: _scheduledDate == null
                ? const Color(0xFF9CA3AF)
                : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildWalletPicker() {
    final accounts = context.watch<FundAccountProvider>().activeAccounts;
    return DropdownButtonFormField<String>(
      initialValue:
          accounts.any((a) => a.id == _fundAccountId) ? _fundAccountId : null,
      isExpanded: true,
      decoration: _inputDecoration('Pay from wallet'),
      items: accounts
          .map(
            (a) => DropdownMenuItem(
              value: a.id,
              child: Text(
                a.name,
                style: GoogleFonts.inter(fontSize: 13.sp),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (id) {
        final account = accounts.where((a) => a.id == id).firstOrNull;
        setState(() {
          _fundAccountId = account?.id;
          _fundAccountName = account?.name;
        });
      },
    );
  }

  Widget _buildPaymentMethodPicker() {
    return DropdownButtonFormField<String>(
      initialValue: _paymentMethod,
      isExpanded: true,
      decoration: _inputDecoration('Payment method'),
      items: [
        DropdownMenuItem(
          value: 'cash',
          child: Text('Cash', style: GoogleFonts.inter(fontSize: 13.sp)),
        ),
        DropdownMenuItem(
          value: 'stcPay',
          child: Text('STC Pay', style: GoogleFonts.inter(fontSize: 13.sp)),
        ),
      ],
      onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
    );
  }

  // ─── Lines ───────────────────────────────────────────────────

  Widget _buildLinesEditor() {
    final types = context.watch<VehicleProvider>().maintenanceTypes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _lines.length; i++) ...[
          _buildLineRow(i, types),
          if (i < _lines.length - 1) Divider(height: 24.h),
        ],
        SizedBox(height: 12.h),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _lines.add(_LineDraft())),
              icon: Icon(Icons.add, size: 16.sp),
              label: Text(
                'Add item',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Estimate  ${_estimatedTotal.toStringAsFixed(2)} SAR',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_showActuals)
                  Text(
                    'Actual  ${_actualTotal.toStringAsFixed(2)} SAR',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: _actualTotal > _estimatedTotal
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF059669),
                    ),
                  ),
              ],
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          'Each item becomes its own maintenance record when the work order '
          'closes, so every service interval resets correctly.',
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildLineRow(int index, List<MaintenanceTypeEntity> types) {
    final line = _lines[index];
    final isOther = line.maintenanceTypeId == kOtherTypeId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                initialValue: _resolveTypeValue(line, types),
                isExpanded: true,
                decoration: _inputDecoration('Item *'),
                items: [
                  ...types.map(
                    (t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(
                        t.name,
                        style: GoogleFonts.inter(fontSize: 13.sp),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: kCarWashTypeId,
                    child: Text(
                      'Car Wash',
                      style: GoogleFonts.inter(fontSize: 13.sp),
                    ),
                  ),
                  DropdownMenuItem(
                    value: kOtherTypeId,
                    child: Text(
                      'Other…',
                      style: GoogleFonts.inter(fontSize: 13.sp),
                    ),
                  ),
                ],
                validator: (v) => v == null ? 'Required' : null,
                onChanged: (v) =>
                    setState(() => line.maintenanceTypeId = v),
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: line.estimate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: _inputDecoration('Estimate'),
              ),
            ),
            if (_showActuals) ...[
              SizedBox(width: 8.w),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: line.actual,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDecoration('Actual'),
                ),
              ),
            ],
            if (_lines.length > 1)
              IconButton(
                tooltip: 'Remove item',
                icon: Icon(
                  Icons.close,
                  size: 18.sp,
                  color: const Color(0xFF9CA3AF),
                ),
                onPressed: () => setState(() {
                  _lines.removeAt(index).dispose();
                }),
              ),
          ],
        ),
        if (isOther) ...[
          SizedBox(height: 8.h),
          TextFormField(
            controller: line.customName,
            decoration: _inputDecoration('Describe the item *'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Name this item'
                : null,
          ),
        ],
        if (_showActuals) ...[
          SizedBox(height: 8.h),
          Row(
            children: [
              Checkbox(
                value: line.completed,
                visualDensity: VisualDensity.compact,
                onChanged: (v) =>
                    setState(() => line.completed = v ?? true),
              ),
              Text(
                'Carried out',
                style: GoogleFonts.inter(fontSize: 12.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: TextFormField(
                  controller: line.parts,
                  decoration: _inputDecoration('Parts replaced'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String? _resolveTypeValue(
    _LineDraft line,
    List<MaintenanceTypeEntity> types,
  ) {
    final id = line.maintenanceTypeId;
    if (id == null) return null;
    if (id == kCarWashTypeId || id == kOtherTypeId) return id;
    // Guard against a type that was deleted from master data since the work
    // order was written — a stale value would trip the dropdown assertion.
    return types.any((t) => t.id == id) ? id : null;
  }

  // ─── Save ────────────────────────────────────────────────────

  Widget _buildBottomBar(bool autoApproves) {
    final isSubmitting = context.watch<WorkOrderProvider>().isSubmitting;
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: const Color(0xFFE5E7EB))),
        ),
        child: Row(
          children: [
            if (autoApproves)
              Expanded(
                child: Text(
                  'Under the auto-approve limit — this will be approved '
                  'automatically.',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color: const Color(0xFF059669),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              const Spacer(),
            SizedBox(width: 12.w),
            ElevatedButton(
              onPressed: isSubmitting ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: isSubmitting
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEdit ? 'Save Changes' : 'Create Work Order',
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<WorkOrderLine> _buildLines(List<MaintenanceTypeEntity> types) {
    const writer = MaintenanceHistoryWriter();
    return _lines
        .where((l) => l.maintenanceTypeId != null)
        .map(
          (l) => WorkOrderLine(
            id: l.id,
            maintenanceTypeId: l.maintenanceTypeId!,
            maintenanceTypeName: writer.resolveTypeName(
              typeId: l.maintenanceTypeId!,
              types: types,
              customName: l.customName.text,
            ),
            customTypeName: l.maintenanceTypeId == kOtherTypeId
                ? l.customName.text.trim()
                : null,
            estimatedCost: double.tryParse(l.estimate.text.trim()) ?? 0,
            actualCost: double.tryParse(l.actual.text.trim()),
            partsReplaced:
                l.parts.text.trim().isEmpty ? null : l.parts.text.trim(),
            notes: l.notes.text.trim().isEmpty ? null : l.notes.text.trim(),
            completed: l.completed,
          ),
        )
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final vehicle = _vehicle;
    if (vehicle == null) {
      AppSnackBar.showWarning(context, 'Pick a vehicle first.');
      return;
    }
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final provider = context.read<WorkOrderProvider>();
    final policy = context.read<FinanceProvider>().policy;
    final types = context.read<VehicleProvider>().maintenanceTypes;
    final lines = _buildLines(types);
    final odometer = int.tryParse(_odometer.text.trim());

    if (_isEdit) {
      final existing = widget.workOrder!;
      final updated = existing.copyWith(
        complaint: _complaint.text.trim(),
        priority: _priority,
        lines: lines,
        shopId: _shopId,
        shopName: _shopName,
        scheduledDate: _scheduledDate,
        clearShop: _shopId == null,
        clearScheduledDate: _scheduledDate == null,
        odometerAtService: odometer,
        shopInvoiceNumber: _invoiceNumber.text.trim().isEmpty
            ? null
            : _invoiceNumber.text.trim(),
        fundAccountId: _fundAccountId,
        fundAccountName: _fundAccountName,
        paymentMethod: _paymentMethod,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      final saved = await provider.saveDetails(
        workOrder: updated,
        actor: user,
      );
      if (!mounted) return;
      if (saved == null) {
        AppSnackBar.showError(context, provider.error ?? 'Could not save.');
        return;
      }
      AppSnackBar.showSuccess(context, 'Work order updated.');
      Navigator.pop(context, true);
      return;
    }

    final created = await provider.createWorkOrder(
      vehicle: vehicle,
      complaint: _complaint.text.trim(),
      actor: user,
      policy: policy,
      source: widget.initialMaintenanceTypeId != null
          ? WorkOrderSource.alert
          : WorkOrderSource.adhoc,
      priority: _priority,
      lines: lines,
      shopId: _shopId,
      shopName: _shopName,
      scheduledDate: _scheduledDate,
      odometerAtRequest: odometer,
      sourceAlertTypeId: widget.initialMaintenanceTypeId,
      fundAccountId: _fundAccountId,
      fundAccountName: _fundAccountName,
      paymentMethod: _paymentMethod,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );

    if (!mounted) return;
    if (created == null) {
      AppSnackBar.showError(context, provider.error ?? 'Could not create.');
      return;
    }
    AppSnackBar.showSuccess(
      context,
      '${created.workOrderNumber} created · ${created.status.displayName}',
    );
    Navigator.pop(context, true);
  }
}
