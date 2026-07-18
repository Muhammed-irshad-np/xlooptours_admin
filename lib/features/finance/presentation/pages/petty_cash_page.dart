import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/petty_cash_provider.dart';
import '../providers/fund_account_provider.dart';
import '../../domain/entities/petty_cash_session_entity.dart';
import '../../domain/entities/fund_account_entity.dart';
import 'finance_dashboard_page.dart';

/// Screen for managing daily petty cash open/close flows and verification.
class PettyCashPage extends StatefulWidget {
  const PettyCashPage({super.key});

  @override
  State<PettyCashPage> createState() => _PettyCashPageState();
}

class _PettyCashPageState extends State<PettyCashPage> {
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accProv = context.read<FundAccountProvider>();
      final pettyAccounts = accProv.activeAccounts
          .where((a) => a.type == FundAccountType.pettyCash)
          .toList();

      if (pettyAccounts.isNotEmpty) {
        setState(() => _selectedAccountId = pettyAccounts.first.id);
        context.read<PettyCashProvider>().loadSessions(pettyAccounts.first.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accProv = context.watch<FundAccountProvider>();
    final pettyAccounts = accProv.activeAccounts
        .where((a) => a.type == FundAccountType.pettyCash)
        .toList();

    return Consumer<PettyCashProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account selection dropdown
            _buildAccountSelector(pettyAccounts, provider),
            SizedBox(height: 20.h),

            if (_selectedAccountId == null)
              _buildNoPettyAccounts()
            else ...[
              // Current Session Status Card
              _buildCurrentSessionCard(context, provider),
              SizedBox(height: 24.h),

              // Sessions History
              _buildSessionsHistory(context, provider),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAccountSelector(
    List<FundAccountEntity> accounts,
    PettyCashProvider provider,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Row(
        children: [
          Text(
            'Select Petty Cash Account:',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: FinDT.textPrimary,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedAccountId,
                items: accounts
                    .map((a) => DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.name} (${a.code})'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedAccountId = v);
                    provider.loadSessions(v);
                  }
                },
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: FinDT.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPettyAccounts() {
    return Container(
      padding: EdgeInsets.all(40.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Center(
        child: Text(
          'Please create a Petty Cash account in the Accounts tab first.',
          style: GoogleFonts.inter(fontSize: 13.sp, color: FinDT.textSecondary),
        ),
      ),
    );
  }

  Widget _buildCurrentSessionCard(BuildContext context, PettyCashProvider provider) {
    final session = provider.currentSession;
    final formatter = NumberFormat('#,##0.00', 'en_US');

    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: FinDT.border),
        boxShadow: [
          BoxShadow(
            color: FinDT.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Petty Cash Session',
                    style: GoogleFonts.inter(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: FinDT.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    session != null
                        ? 'Opened on ${DateFormat('dd MMM yyyy').format(session.date)}'
                        : 'No session currently open',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      color: FinDT.textSecondary,
                    ),
                  ),
                ],
              ),
              if (session != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: FinDT.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    'Active',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: FinDT.success,
                    ),
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: FinDT.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    'Closed',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: FinDT.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 20.h),
          if (session != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSessionStat('Opening Balance', '${formatter.format(session.openingBalance)} SAR'),
                _buildSessionStat('Total Expenses Today', '${formatter.format(session.totalExpenses)} SAR'),
                _buildSessionStat('Total Deposits Today', '${formatter.format(session.deposits)} SAR'),
                _buildSessionStat(
                  'Expected Closing',
                  '${formatter.format(session.expectedClosingBalance)} SAR',
                  highlight: true,
                ),
              ],
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showCloseSessionDialog(context, provider, session),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FinDT.brand,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(
                      'Close Session & Declare Balance',
                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showOpenSessionDialog(context, provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FinDT.brand,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(
                      'Open Daily Session',
                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSessionStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            color: FinDT.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: highlight ? 18.sp : 15.sp,
            fontWeight: FontWeight.w700,
            color: highlight ? FinDT.brand : FinDT.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionsHistory(BuildContext context, PettyCashProvider provider) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: FinDT.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Text(
              'Session Logs & Closings',
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: FinDT.textPrimary,
              ),
            ),
          ),
          Divider(height: 1, color: FinDT.borderLight),
          if (provider.sessions.isEmpty)
            Padding(
              padding: EdgeInsets.all(40.w),
              child: Center(
                child: Text(
                  'No historical sessions found',
                  style: GoogleFonts.inter(fontSize: 13.sp, color: FinDT.textSecondary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: provider.sessions.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: FinDT.borderLight),
              itemBuilder: (context, index) {
                final session = provider.sessions[index];
                final isClosed = session.status == PettyCashSessionStatus.closed;
                final isVerified = session.status == PettyCashSessionStatus.verified;

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                  child: Row(
                    children: [
                      Icon(
                        isVerified ? Icons.check_circle_outline : Icons.pending_outlined,
                        color: isVerified ? FinDT.success : FinDT.warning,
                        size: 20.sp,
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Session: ${DateFormat('dd MMMM yyyy').format(session.date)}',
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: FinDT.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Expected: ${formatter.format(session.expectedClosingBalance)} | Declared: ${formatter.format(session.closingBalance)}',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: FinDT.textSecondary,
                              ),
                            ),
                            if (session.discrepancy != null && session.discrepancy != 0) ...[
                              SizedBox(height: 2.h),
                              Text(
                                'Discrepancy: ${session.discrepancy! > 0 ? "+" : ""}${formatter.format(session.discrepancy)} SAR',
                                style: GoogleFonts.inter(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: session.discrepancy! >= 0 ? FinDT.success : FinDT.danger,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isClosed)
                        ElevatedButton(
                          onPressed: () => _confirmVerifySession(context, provider, session),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FinDT.success,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            'Verify Closing',
                            style: GoogleFonts.inter(fontSize: 11.sp, fontWeight: FontWeight.w600),
                          ),
                        )
                      else if (isVerified)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: FinDT.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            'Verified',
                            style: GoogleFonts.inter(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: FinDT.success,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── Daily Open / Close Dialogs ─────────────────────────────

  void _showOpenSessionDialog(BuildContext context, PettyCashProvider provider) {
    final formKey = GlobalKey<FormState>();
    final openingCtrl = TextEditingController();

    // Default opening balance based on the current balance of the account
    final accProv = context.read<FundAccountProvider>();
    final selectedAcc = accProv.getAccountById(_selectedAccountId ?? '');
    if (selectedAcc != null) {
      openingCtrl.text = selectedAcc.currentBalance.toString();
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Daily Session'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: openingCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Opening Balance *',
                  suffixText: 'SAR',
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final session = PettyCashSessionEntity(
                id: const Uuid().v4(),
                fundAccountId: _selectedAccountId!,
                date: DateTime.now(),
                openedBy: 'Admin',
                openingBalance: double.parse(openingCtrl.text),
                createdAt: DateTime.now(),
              );

              provider.openSession(session);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: FinDT.brand),
            child: const Text('Open Session'),
          ),
        ],
      ),
    );
  }

  void _showCloseSessionDialog(
    BuildContext context,
    PettyCashProvider provider,
    PettyCashSessionEntity session,
  ) {
    final formKey = GlobalKey<FormState>();
    final cashCtrl = TextEditingController();
    final digitalCtrl = TextEditingController();
    final otherCtrl = TextEditingController();
    String? closingSheetUrl;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Close Daily Session'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Expected Closing: ${session.expectedClosingBalance.toStringAsFixed(2)} SAR',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: FinDT.brand),
                  ),
                  SizedBox(height: 16.h),
                  TextFormField(
                    controller: cashCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(labelText: 'Physical Cash in Hand *'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: digitalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(labelText: 'STC Pay Balance'),
                  ),
                  SizedBox(height: 12.h),
                  TextFormField(
                    controller: otherCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    decoration: const InputDecoration(labelText: 'Other Digital Balance'),
                  ),
                  SizedBox(height: 16.h),
                  // Closing Sheet Upload
                  if (closingSheetUrl != null)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: FinDT.bgPage,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: FinDT.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.insert_drive_file_outlined, color: FinDT.brand, size: 16.sp),
                          SizedBox(width: 8.w),
                          const Expanded(child: Text('Closing Sheet Attached')),
                          IconButton(
                            onPressed: () => setStateDialog(() => closingSheetUrl = null),
                            icon: Icon(Icons.close, color: FinDT.danger, size: 16.sp),
                          ),
                        ],
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final file = await picker.pickImage(source: ImageSource.gallery);
                        if (file != null) {
                          final url = await provider.uploadClosingSheet(file, session.id);
                          setStateDialog(() => closingSheetUrl = url);
                        }
                      },
                      icon: Icon(Icons.upload_file, size: 16.sp),
                      label: const Text('Upload Daily Sheet'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        minimumSize: Size(double.infinity, 44.h),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final cash = double.parse(cashCtrl.text);
                final digital = double.tryParse(digitalCtrl.text) ?? 0.0;
                final other = double.tryParse(otherCtrl.text) ?? 0.0;
                final closing = cash + digital + other;

                final closed = session.copyWith(
                  closingBalance: closing,
                  cashInHand: cash,
                  stcPayBalance: digital,
                  otherDigitalBalance: other,
                  closingSheetUrl: closingSheetUrl,
                  closedBy: 'Admin',
                );

                provider.closeSession(closed);
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: FinDT.brand),
              child: const Text('Close Session'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmVerifySession(
    BuildContext context,
    PettyCashProvider provider,
    PettyCashSessionEntity session,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Daily Closing?'),
        content: Text(
          'Confirm that the declared closing balance of ${session.closingBalance.toStringAsFixed(2)} SAR matches the daily receipts and cash in hand.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              provider.verifySession(session.id, 'Admin');
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: FinDT.success),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }
}
