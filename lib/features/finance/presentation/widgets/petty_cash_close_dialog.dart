import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/expense_entity.dart';
import '../../domain/entities/finance_policy_entity.dart';
import '../../domain/entities/fund_account_entity.dart';
import '../../domain/entities/ledger_day_totals.dart';
import '../../domain/entities/petty_cash_close_request.dart';
import '../../domain/entities/petty_cash_session_entity.dart';
import '../../domain/services/petty_cash_close_calculator.dart';
import '../pages/finance_dashboard_page.dart';
import '../providers/petty_cash_provider.dart';
import 'finance_dialog_helpers.dart';

typedef _Calc = PettyCashCloseCalculator;

/// Opens the two-step "Close Daily Register" dialog. Returns the closed
/// session, or null when the closer cancels.
Future<PettyCashSessionEntity?> showPettyCashCloseDialog({
  required BuildContext context,
  required PettyCashProvider provider,
  required PettyCashSessionEntity session,
  required FinancePolicyEntity policy,
  required String closedBy,
  required String? closedByUserId,
  required bool canApproveLargeVariance,
  required VoidCallback onViewExpenses,
}) {
  return showDialog<PettyCashSessionEntity>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PettyCashCloseDialog(
      provider: provider,
      session: session,
      policy: policy,
      closedBy: closedBy,
      closedByUserId: closedByUserId,
      canApproveLargeVariance: canApproveLargeVariance,
      onViewExpenses: onViewExpenses,
    ),
  );
}

/// Step 1: count Cash and STC Pay (fields start empty, nothing to copy).
/// Step 2: compare with the account, explain any difference, close.
class PettyCashCloseDialog extends StatefulWidget {
  final PettyCashProvider provider;
  final PettyCashSessionEntity session;
  final FinancePolicyEntity policy;
  final String closedBy;
  final String? closedByUserId;
  final bool canApproveLargeVariance;
  final VoidCallback onViewExpenses;

  const PettyCashCloseDialog({
    super.key,
    required this.provider,
    required this.session,
    required this.policy,
    required this.closedBy,
    required this.closedByUserId,
    required this.canApproveLargeVariance,
    required this.onViewExpenses,
  });

  @override
  State<PettyCashCloseDialog> createState() => _PettyCashCloseDialogState();
}

class _PettyCashCloseDialogState extends State<PettyCashCloseDialog> {
  static const _noteValues = [500, 200, 100, 50, 20, 10, 5, 1];
  static const _stcColor = Color(0xFF7C3AED);
  static const _cashColor = Color(0xFF16A34A);

  final _fmt = NumberFormat('#,##0.00', 'en_US');

  int _step = 1;

  // Step 1 — the count
  final _cashCtrl = TextEditingController();
  final _stcCtrl = TextEditingController();
  bool _countByNotes = false;
  final Map<int, TextEditingController> _noteCtrls = {
    for (final v in _noteValues) v: TextEditingController(),
  };
  final _coinsCtrl = TextEditingController();
  int _recountCount = 0;
  int? _firstCountCash;
  int? _firstCountStc;

  // Step 2 — the comparison
  bool _loading = false;
  String? _loadError;
  FundAccountEntity? _account;
  LedgerDayTotals? _totals;
  List<ExpenseEntity> _unposted = const [];
  bool? _transferAnswer; // null = not answered, true = yes, false = no
  final _transferCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _showBreakdown = false;
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _cashCtrl.dispose();
    _stcCtrl.dispose();
    for (final c in _noteCtrls.values) {
      c.dispose();
    }
    _coinsCtrl.dispose();
    _transferCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  // ─── Count helpers ───────────────────────────────────────────

  /// Cash total from the note counter, or null when nothing is entered.
  int? get _notesTotalMinor {
    var total = 0;
    var any = false;
    for (final v in _noteValues) {
      final t = _noteCtrls[v]!.text.trim();
      if (t.isEmpty) continue;
      final qty = int.tryParse(t);
      if (qty == null || qty < 0) return null;
      any = true;
      total += qty * v * 100;
    }
    final coinsText = _coinsCtrl.text.trim();
    if (coinsText.isNotEmpty) {
      final coins = _Calc.parseMinor(coinsText);
      if (coins == null) return null;
      any = true;
      total += coins;
    }
    return any ? total : null;
  }

  int? get _countedCash =>
      _countByNotes ? _notesTotalMinor : _Calc.parseMinor(_cashCtrl.text);
  int? get _countedStc => _Calc.parseMinor(_stcCtrl.text);

  void _onNotesChanged() {
    final total = _notesTotalMinor;
    _cashCtrl.text = total == null ? '' : _Calc.formatPlain(total);
    setState(() {});
  }

  // ─── Step navigation ─────────────────────────────────────────

  Future<void> _goToCompare() async {
    if (_countedCash == null || _countedStc == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step = 2;
      _transferAnswer = null;
      _transferCtrl.clear();
      _submitError = null;
    });
    await _loadExpected();
  }

  Future<void> _loadExpected() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final id = widget.session.fundAccountId;
      final results = await Future.wait<Object>([
        widget.provider.fetchLiveAccount(id),
        widget.provider.financeRepository.getLedgerDayTotals(
          id,
          widget.session.date,
          sessionOpenedAt: widget.session.createdAt,
        ),
        widget.provider.getUnpostedExpenses(id),
      ]);
      if (!mounted) return;
      setState(() {
        _account = results[0] as FundAccountEntity;
        _totals = results[1] as LedgerDayTotals;
        _unposted = results[2] as List<ExpenseEntity>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load the account balance: $e';
      });
    }
  }

  void _backToCount() {
    setState(() {
      _step = 1;
      _submitError = null;
    });
  }

  void _startRecount() {
    setState(() {
      _firstCountCash ??= _countedCash;
      _firstCountStc ??= _countedStc;
      _recountCount++;
      _cashCtrl.clear();
      _stcCtrl.clear();
      for (final c in _noteCtrls.values) {
        c.clear();
      }
      _coinsCtrl.clear();
      _transferAnswer = null;
      _transferCtrl.clear();
      _submitError = null;
      _step = 1;
    });
  }

  // ─── Step 2 maths ────────────────────────────────────────────

  /// Signed transfer the pattern suggests (+ Cash→STC, − STC→Cash).
  int? get _suggestedTransfer {
    final acc = _account;
    final cash = _countedCash;
    final stc = _countedStc;
    if (acc == null || cash == null || stc == null) return null;
    return _Calc.suggestedTransferCashToStc(
      cashDiffMinor: cash - acc.cashBalanceMinor,
      stcDiffMinor: stc - acc.stcPayBalanceMinor,
    );
  }

  /// The transfer the closer confirmed, 0 when none, null when the typed
  /// amount is invalid.
  int? get _transferMinor {
    final suggested = _suggestedTransfer;
    if (suggested == null || _transferAnswer != true) return 0;
    final typed = _Calc.parseMinor(_transferCtrl.text);
    if (typed == null || typed <= 0 || typed > suggested.abs()) return null;
    return suggested > 0 ? typed : -typed;
  }

  PettyCashClosePlan? get _plan {
    final acc = _account;
    final cash = _countedCash;
    final stc = _countedStc;
    final transfer = _transferMinor;
    if (acc == null || cash == null || stc == null || transfer == null) {
      return null;
    }
    try {
      return _Calc.plan(
        accountTotalMinor: acc.currentBalanceMinor,
        accountCashMinor: acc.cashBalanceMinor,
        accountStcMinor: acc.stcPayBalanceMinor,
        countedCashMinor: cash,
        countedStcMinor: stc,
        transferCashToStcMinor: transfer,
      );
    } on StateError {
      return null;
    }
  }

  // ─── Submit ──────────────────────────────────────────────────

  Future<void> _submit(PettyCashClosePlan plan) async {
    final acc = _account!;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final closed = await widget.provider.closeSession(
        PettyCashCloseRequest(
          sessionId: widget.session.id,
          countedCashMinor: plan.countedCashMinor,
          countedStcMinor: plan.countedStcMinor,
          seenAccountCashMinor: acc.cashBalanceMinor,
          seenAccountStcMinor: acc.stcPayBalanceMinor,
          transferCashToStcMinor: plan.transferCashToStcMinor,
          notes: _reasonCtrl.text.trim(),
          recountCount: _recountCount,
          firstCountCashMinor: _recountCount > 0 ? _firstCountCash : null,
          firstCountStcMinor: _recountCount > 0 ? _firstCountStc : null,
          closedBy: widget.closedBy,
          closedByUserId: widget.closedByUserId,
          closerCanApproveLargeVariance: widget.canApproveLargeVariance,
        ),
      );
      if (mounted) Navigator.of(context).pop(closed);
    } catch (e) {
      if (!mounted) return;
      // On web an error raised inside a Firestore transaction can lose its
      // type, so compare balances again rather than trusting the error type.
      final seenCash = acc.cashBalanceMinor;
      final seenStc = acc.stcPayBalanceMinor;
      await _loadExpected();
      if (!mounted) return;
      final latest = _account;
      setState(() {
        _submitting = false;
        if (latest != null &&
            (latest.cashBalanceMinor != seenCash ||
                latest.stcPayBalanceMinor != seenStc)) {
          _transferAnswer = null;
          _transferCtrl.clear();
          _submitError = PettyCashBalancesChangedError(
            accountCashMinor: latest.cashBalanceMinor,
            accountStcMinor: latest.stcPayBalanceMinor,
          ).message;
        } else {
          _submitError = e is StateError ? e.message : '$e';
        }
      });
    }
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: finDialogShape,
      title: finDialogTitle(
        'Close Daily Register',
        icon: Icons.lock_clock_outlined,
      ),
      content: SizedBox(
        width: 520.w,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepHeader(),
              SizedBox(height: 14.h),
              if (_step == 1) ..._buildCountStep() else ..._buildCompareStep(),
            ],
          ),
        ),
      ),
      actions: _step == 1 ? _countActions() : _compareActions(),
    );
  }

  Widget _stepHeader() {
    Widget dot(int n, String label) {
      final active = _step == n;
      final done = _step > n;
      final color = active || done ? FinDT.brand : FinDT.textMuted;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10.r,
            backgroundColor: active || done ? FinDT.brand : FinDT.borderLight,
            child: done
                ? Icon(Icons.check, size: 12.sp, color: Colors.white)
                : Text(
                    '$n',
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : FinDT.textMuted,
                    ),
                  ),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        dot(1, 'Count'),
        Expanded(
          child: Container(
            height: 1,
            margin: EdgeInsets.symmetric(horizontal: 10.w),
            color: FinDT.border,
          ),
        ),
        dot(2, 'Compare & close'),
      ],
    );
  }

  // ─── Step 1 UI ───────────────────────────────────────────────

  List<Widget> _buildCountStep() {
    return [
      Text(
        'Count the cash in the drawer and check the STC Pay balance in the '
        'app. Enter exactly what you have - the system amount is shown on '
        'the next step.',
        style: GoogleFonts.inter(fontSize: 11.sp, color: FinDT.textSecondary),
      ),
      if (_recountCount > 0) ...[
        SizedBox(height: 10.h),
        _notice(
          color: FinDT.warning,
          icon: Icons.replay_rounded,
          text: 'Recount: count everything again from the start. '
              'First count was Cash ${_fmt.format((_firstCountCash ?? 0) / 100)} '
              'and STC Pay ${_fmt.format((_firstCountStc ?? 0) / 100)} SAR.',
        ),
      ],
      SizedBox(height: 14.h),
      _amountField(
        controller: _cashCtrl,
        label: 'Physical cash in hand',
        icon: Icons.payments_outlined,
        readOnly: _countByNotes,
        autofocus: true,
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            setState(() => _countByNotes = !_countByNotes);
            if (_countByNotes) _onNotesChanged();
          },
          icon: Icon(
            _countByNotes ? Icons.expand_less : Icons.calculate_outlined,
            size: 16.sp,
          ),
          label: Text(
            _countByNotes ? 'Type the total instead' : 'Count by notes',
            style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      if (_countByNotes) _notesCounter(),
      SizedBox(height: 10.h),
      _amountField(
        controller: _stcCtrl,
        label: 'STC Pay balance (from the app)',
        icon: Icons.phone_android_outlined,
      ),
    ];
  }

  Widget _notesCounter() {
    return Container(
      padding: EdgeInsets.all(10.w),
      margin: EdgeInsets.only(bottom: 4.h),
      decoration: BoxDecoration(
        color: FinDT.bgPage,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final v in _noteValues)
                SizedBox(
                  width: 110.w,
                  child: TextField(
                    controller: _noteCtrls[v],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _onNotesChanged(),
                    style: GoogleFonts.inter(fontSize: 12.sp),
                    decoration: finDialogInputDecoration(
                      label: '$v SAR ×',
                      hint: '0',
                    ),
                  ),
                ),
              SizedBox(
                width: 140.w,
                child: TextField(
                  controller: _coinsCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [_decimalFormatter],
                  onChanged: (_) => _onNotesChanged(),
                  style: GoogleFonts.inter(fontSize: 12.sp),
                  decoration: finDialogInputDecoration(
                    label: 'Coins (SAR)',
                    hint: '0.00',
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Total: ${_fmt.format((_notesTotalMinor ?? 0) / 100)} SAR',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: FinDT.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _countActions() {
    final ready = _countedCash != null && _countedStc != null;
    return [
      finDialogCancelButton(context),
      finDialogActionButton(
        onPressed: ready ? _goToCompare : null,
        label: 'Next: Compare',
        icon: Icons.arrow_forward_rounded,
      ),
    ];
  }

  // ─── Step 2 UI ───────────────────────────────────────────────

  List<Widget> _buildCompareStep() {
    if (_loading && _account == null) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 30.h),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_loadError != null && _account == null) {
      return [
        _notice(color: FinDT.danger, icon: Icons.error_outline, text: _loadError!),
        SizedBox(height: 8.h),
        TextButton(onPressed: _loadExpected, child: const Text('Try again')),
      ];
    }
    final acc = _account!;
    final plan = _plan;
    final suggested = _suggestedTransfer;
    final checks = plan == null
        ? null
        : _Calc.checks(
            cashVarianceMinor: plan.cashVarianceMinor,
            stcVarianceMinor: plan.stcVarianceMinor,
            recountAboveMinor: _Calc.toMinor(widget.policy.pettyCashRecountAbove),
            adminCloseAboveMinor:
                _Calc.toMinor(widget.policy.pettyCashAdminCloseAbove),
          );

    return [
      _comparisonTable(acc, plan),
      SizedBox(height: 8.h),
      _breakdownToggle(acc),
      if (_unposted.isNotEmpty) ...[
        SizedBox(height: 10.h),
        _unpostedNotice(),
      ],
      if (suggested != null) ...[
        SizedBox(height: 12.h),
        _transferQuestion(suggested),
      ],
      if (plan != null) ...[
        SizedBox(height: 12.h),
        _statusBanner(plan),
      ],
      if (checks != null && checks.needsRecount && _recountCount == 0) ...[
        SizedBox(height: 10.h),
        _notice(
          color: FinDT.warning,
          icon: Icons.replay_rounded,
          text: 'The difference is more than '
              '${_fmt.format(widget.policy.pettyCashRecountAbove)} SAR. '
              'Count everything again before closing.',
        ),
      ],
      if (checks != null &&
          checks.needsAdmin &&
          !widget.canApproveLargeVariance) ...[
        SizedBox(height: 10.h),
        _notice(
          color: FinDT.danger,
          icon: Icons.admin_panel_settings_outlined,
          text: 'The difference is more than '
              '${_fmt.format(widget.policy.pettyCashAdminCloseAbove)} SAR. '
              'An admin must close this register.',
        ),
      ],
      SizedBox(height: 12.h),
      TextField(
        controller: _reasonCtrl,
        maxLines: 2,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.inter(fontSize: 12.sp, color: FinDT.textPrimary),
        decoration: finDialogInputDecoration(
          label: (checks?.needsReason ?? false)
              ? 'Why is there a difference? *'
              : 'Closing remarks (optional)',
          hint: (checks?.needsReason ?? false)
              ? 'e.g. unrecorded voucher, wrong change given, damaged note'
              : 'Any remarks',
          prefixIcon: Icons.edit_note_rounded,
        ),
      ),
      if (_submitError != null) ...[
        SizedBox(height: 10.h),
        _notice(color: FinDT.danger, icon: Icons.error_outline, text: _submitError!),
      ],
    ];
  }

  Widget _comparisonTable(FundAccountEntity acc, PettyCashClosePlan? plan) {
    final cash = _countedCash ?? 0;
    final stc = _countedStc ?? 0;
    final expCash = plan?.expectedCashMinor ?? acc.cashBalanceMinor;
    final expStc = plan?.expectedStcMinor ?? acc.stcPayBalanceMinor;
    final transfer = plan?.transferCashToStcMinor ?? 0;

    TableRow row(String label, int expected, int counted,
        {Color? color, bool bold = false}) {
      final diff = counted - expected;
      final style = GoogleFonts.inter(
        fontSize: 12.sp,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: FinDT.textPrimary,
      );
      return TableRow(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 7.h),
            child: Row(
              children: [
                if (color != null) ...[
                  Container(
                    width: 8.w,
                    height: 8.w,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  SizedBox(width: 6.w),
                ],
                Text(label, style: style),
              ],
            ),
          ),
          Text(_fmt.format(expected / 100), style: style, textAlign: TextAlign.right),
          Text(_fmt.format(counted / 100), style: style, textAlign: TextAlign.right),
          _diffText(diff, bold: bold),
        ],
      );
    }

    final header = GoogleFonts.inter(
      fontSize: 10.sp,
      fontWeight: FontWeight.w600,
      color: FinDT.textSecondary,
    );
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
      decoration: BoxDecoration(
        color: FinDT.bgPage,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.1),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(children: [
                Text('', style: header),
                Text('Expected', style: header, textAlign: TextAlign.right),
                Text('Counted', style: header, textAlign: TextAlign.right),
                Text('Difference', style: header, textAlign: TextAlign.right),
              ]),
              row('Cash', expCash, cash, color: _cashColor),
              row('STC Pay', expStc, stc, color: _stcColor),
              TableRow(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: FinDT.border)),
                ),
                children: List.generate(4, (_) => SizedBox(height: 2.h)),
              ),
              row('Total', expCash + expStc, cash + stc, bold: true),
            ],
          ),
          if (transfer != 0)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Text(
                'Expected includes ${_fmt.format(transfer.abs() / 100)} SAR moved '
                '${transfer > 0 ? 'Cash → STC Pay' : 'STC Pay → Cash'}.',
                style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _diffText(int diff, {bool bold = false}) {
    final color = diff == 0
        ? FinDT.success
        : (diff < 0 ? FinDT.danger : const Color(0xFF2563EB));
    final text = diff == 0
        ? '0.00'
        : '${diff > 0 ? '+' : '−'}${_fmt.format(diff.abs() / 100)}';
    return Text(
      text,
      textAlign: TextAlign.right,
      style: GoogleFonts.inter(
        fontSize: 12.sp,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
        color: color,
      ),
    );
  }

  /// Opening + money in − money out (from the ledger), and whatever else
  /// moved the account (transfers, adjustments, voids), which together give
  /// the expected amount.
  Widget _breakdownToggle(FundAccountEntity acc) {
    final t = _totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _showBreakdown = !_showBreakdown),
              icon: Icon(
                _showBreakdown ? Icons.expand_less : Icons.expand_more,
                size: 16.sp,
              ),
              label: Text(
                'How the expected amount is worked out',
                style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: widget.onViewExpenses,
              icon: Icon(Icons.receipt_long_rounded, size: 14.sp),
              label: Text(
                "Today's expenses",
                style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (_showBreakdown && t != null) _breakdownTable(acc, t),
      ],
    );
  }

  Widget _breakdownTable(FundAccountEntity acc, LedgerDayTotals t) {
    final s = widget.session;
    final openCash = _Calc.toMinor(s.openingCashBalance);
    final openStc = _Calc.toMinor(s.openingStcPayBalance);
    final inCash = _Calc.toMinor(t.cashDeposits);
    final inStc = _Calc.toMinor(t.stcPayDeposits);
    final outCash = _Calc.toMinor(t.cashExpenses);
    final outStc = _Calc.toMinor(t.stcPayExpenses);
    final otherCash = acc.cashBalanceMinor - (openCash + inCash - outCash);
    final otherStc = acc.stcPayBalanceMinor - (openStc + inStc - outStc);

    TableRow row(String label, int cash, int stc, {bool bold = false, bool signed = false}) {
      String f(int v) => signed && v != 0
          ? '${v > 0 ? '+' : '−'}${_fmt.format(v.abs() / 100)}'
          : _fmt.format(v / 100);
      final style = GoogleFonts.inter(
        fontSize: 11.sp,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: FinDT.textPrimary,
      );
      return TableRow(children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Text(label, style: style),
        ),
        Text(f(cash), style: style, textAlign: TextAlign.right),
        Text(f(stc), style: style, textAlign: TextAlign.right),
      ]);
    }

    final header = GoogleFonts.inter(
      fontSize: 10.sp,
      fontWeight: FontWeight.w600,
      color: FinDT.textSecondary,
    );
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.8),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
        },
        children: [
          TableRow(children: [
            Text('', style: header),
            Text('Cash', style: header, textAlign: TextAlign.right),
            Text('STC Pay', style: header, textAlign: TextAlign.right),
          ]),
          row('Opening', openCash, openStc),
          row('+ Money in', inCash, inStc),
          row('− Money out', outCash, outStc),
          if (otherCash != 0 || otherStc != 0)
            row('± Other (transfers, adjustments, voids)', otherCash, otherStc,
                signed: true),
          row('= Expected now', acc.cashBalanceMinor, acc.stcPayBalanceMinor,
              bold: true),
        ],
      ),
    );
  }

  Widget _unpostedNotice() {
    final total = _unposted.fold<int>(0, (s, e) => s + e.resolvedAmountMinor);
    final n = _unposted.length;
    return _notice(
      color: FinDT.warning,
      icon: Icons.hourglass_top_rounded,
      text: '$n expense${n == 1 ? '' : 's'} on this account '
          '(${_fmt.format(total / 100)} SAR) ${n == 1 ? 'is' : 'are'} not paid '
          'from the account yet. If you already handed out the cash, the '
          'count will look short - get ${n == 1 ? 'it' : 'them'} approved '
          'before closing.',
    );
  }

  Widget _transferQuestion(int suggested) {
    final cashToStc = suggested > 0;
    final from = cashToStc ? 'Cash' : 'STC Pay';
    final to = cashToStc ? 'STC Pay' : 'Cash';
    final max = suggested.abs();
    final typed = _Calc.parseMinor(_transferCtrl.text);
    final typedInvalid =
        _transferAnswer == true && (typed == null || typed <= 0 || typed > max);

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: _stcColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: _stcColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded, size: 18.sp, color: _stcColor),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  '$from is short and $to is over. Did you move money from '
                  '$from to $to today?',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: FinDT.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              _choiceChip(
                label: 'Yes, record it',
                selected: _transferAnswer == true,
                onTap: () => setState(() {
                  _transferAnswer = true;
                  if (_Calc.parseMinor(_transferCtrl.text) == null) {
                    _transferCtrl.text = _Calc.formatPlain(max);
                  }
                }),
              ),
              SizedBox(width: 8.w),
              _choiceChip(
                label: 'No',
                selected: _transferAnswer == false,
                onTap: () => setState(() => _transferAnswer = false),
              ),
            ],
          ),
          if (_transferAnswer == true) ...[
            SizedBox(height: 10.h),
            TextField(
              controller: _transferCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_decimalFormatter],
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(fontSize: 12.sp),
              decoration: finDialogInputDecoration(
                label: 'Amount moved $from → $to',
                suffixText: 'SAR',
                prefixIcon: Icons.swap_horiz_rounded,
              ).copyWith(
                errorText: typedInvalid
                    ? 'Enter an amount up to ${_fmt.format(max / 100)}'
                    : null,
              ),
            ),
          ],
          if (_transferAnswer == null)
            Padding(
              padding: EdgeInsets.only(top: 6.h),
              child: Text(
                'Answer this to continue.',
                style: GoogleFonts.inter(fontSize: 10.sp, color: FinDT.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _submitting ? null : onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected ? _stcColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: selected ? _stcColor : FinDT.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _stcColor : FinDT.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _statusBanner(PettyCashClosePlan plan) {
    final total = plan.totalVarianceMinor;
    if (plan.isBalanced) {
      return _notice(
        color: FinDT.success,
        icon: Icons.check_circle_outline,
        text: 'Balanced - Cash and STC Pay both match.',
      );
    }
    if (total == 0) {
      return _notice(
        color: const Color(0xFF2563EB),
        icon: Icons.info_outline,
        text: 'The total matches, but Cash and STC Pay are split differently '
            'from the system. Closing sets them to your count.',
      );
    }
    final shortage = total < 0;
    return _notice(
      color: shortage ? FinDT.danger : const Color(0xFF2563EB),
      icon: shortage ? Icons.trending_down_rounded : Icons.trending_up_rounded,
      text: '${shortage ? 'Shortage' : 'Overage'} of '
          '${_fmt.format(total.abs() / 100)} SAR. Closing sets the account to '
          'your count and records the difference; an admin then decides how '
          'it is settled.',
    );
  }

  List<Widget> _compareActions() {
    final plan = _plan;
    final suggested = _suggestedTransfer;
    final checks = plan == null
        ? null
        : _Calc.checks(
            cashVarianceMinor: plan.cashVarianceMinor,
            stcVarianceMinor: plan.stcVarianceMinor,
            recountAboveMinor: _Calc.toMinor(widget.policy.pettyCashRecountAbove),
            adminCloseAboveMinor:
                _Calc.toMinor(widget.policy.pettyCashAdminCloseAbove),
          );

    final back = TextButton.icon(
      onPressed: _submitting ? null : _backToCount,
      icon: Icon(Icons.arrow_back_rounded, size: 16.sp),
      label: Text(
        'Edit count',
        style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600),
      ),
    );

    if (plan == null || checks == null || _loading) {
      return [
        back,
        finDialogActionButton(onPressed: null, label: 'Close Register'),
      ];
    }

    // The transfer answer can remove the difference, so it comes first.
    if (suggested != null && _transferAnswer == null) {
      return [
        back,
        finDialogActionButton(onPressed: null, label: 'Answer the question above'),
      ];
    }

    if (checks.needsRecount && _recountCount == 0) {
      return [
        back,
        finDialogActionButton(
          onPressed: _submitting ? null : _startRecount,
          label: 'Count Again',
          icon: Icons.replay_rounded,
          backgroundColor: FinDT.warning,
        ),
      ];
    }

    final reasonOk = !checks.needsReason || _reasonCtrl.text.trim().isNotEmpty;
    final adminOk = !checks.needsAdmin || widget.canApproveLargeVariance;
    final canClose = reasonOk && adminOk && !_submitting;

    final total = plan.totalVarianceMinor;
    final label = total == 0
        ? 'Close Register'
        : 'Close with ${_fmt.format(total.abs() / 100)} '
            '${total < 0 ? 'shortage' : 'overage'}';

    return [
      back,
      finDialogActionButton(
        onPressed: canClose ? () => _submit(plan) : null,
        label: label,
        isLoading: _submitting,
        backgroundColor: total < 0 ? FinDT.danger : FinDT.brand,
      ),
    ];
  }

  // ─── Shared widgets ──────────────────────────────────────────

  static final _decimalFormatter =
      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));

  Widget _amountField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_decimalFormatter],
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.inter(
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
        color: FinDT.textPrimary,
      ),
      decoration: finDialogInputDecoration(
        label: '$label *',
        hint: '0.00',
        prefixIcon: icon,
        suffixText: 'SAR',
      ),
    );
  }

  Widget _notice({
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.sp, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                color: FinDT.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
