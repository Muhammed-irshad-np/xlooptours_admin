import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:xloop_invoice/features/finance/domain/entities/fund_account_entity.dart';
import 'package:xloop_invoice/features/finance/domain/entities/petty_cash_session_entity.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/fund_account_provider.dart';
import 'package:xloop_invoice/features/finance/presentation/providers/petty_cash_provider.dart';

/// Page managing daily open/close workflows for Petty Cash accounts,
/// verification by admins, and discrepancy auto-flagging.
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
      final fap = context.read<FundAccountProvider>();
      final pcAccounts = fap.accounts.where((a) => a.type == FundAccountType.pettyCash).toList();
      if (pcAccounts.isNotEmpty) {
        setState(() {
          _selectedAccountId = pcAccounts.first.id;
        });
        context.read<PettyCashProvider>().loadSessions(pcAccounts.first.id);
      }
    });
  }

  void _onAccountChanged(String? accountId) {
    if (accountId != null) {
      setState(() {
        _selectedAccountId = accountId;
      });
      context.read<PettyCashProvider>().loadSessions(accountId);
    }
  }

  void _showOpenSessionDialog(BuildContext context, FundAccountEntity account) {
    final balanceController = TextEditingController(text: account.currentBalance.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
        title: Text('Open Daily Petty Cash', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
              style: GoogleFonts.inter(fontSize: 13.sp, color: const Color(0xFF6B7280)),
            ),
            SizedBox(height: 16.h),
            Text(
              'Opening Balance',
              style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
            ),
            SizedBox(height: 6.h),
            TextField(
              controller: balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              style: GoogleFonts.inter(fontSize: 13.sp),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              final double openingBal = double.tryParse(balanceController.text) ?? 0.0;
              final session = PettyCashSessionEntity(
                id: const Uuid().v4(),
                fundAccountId: account.id,
                date: DateTime.now(),
                openedBy: 'ADMIN',
                openingBalance: openingBal,
                createdAt: DateTime.now(),
                status: PettyCashSessionStatus.open,
              );
              context.read<PettyCashProvider>().openSession(session);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            child: Text('Open Session', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showCloseSessionDialog(BuildContext context, PettyCashSessionEntity session) {
    final formKey = GlobalKey<FormState>();
    final cashController = TextEditingController();
    final stcController = TextEditingController(text: '0.0');
    final otherController = TextEditingController(text: '0.0');
    final notesController = TextEditingController();
    XFile? selectedFile;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              title: Text('Close Daily Petty Cash', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Expected Balance: ${session.expectedClosingBalance.toStringAsFixed(2)} SAR',
                        style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF4F46E5)),
                      ),
                      SizedBox(height: 16.h),
                      _buildDialogTextField(
                        cashController,
                        'Actual Cash in Hand',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        validator: (v) => v!.isEmpty ? 'Enter cash' : null,
                      ),
                      SizedBox(height: 12.h),
                      _buildDialogTextField(
                        stcController,
                        'STC Pay Balance',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      ),
                      SizedBox(height: 12.h),
                      _buildDialogTextField(
                        otherController,
                        'Other Digital Wallet Balance',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      ),
                      SizedBox(height: 16.h),
                      _buildDialogTextField(notesController, 'Notes', maxLines: 2),
                      SizedBox(height: 16.h),
                      // Closing Sheet Upload
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picker = ImagePicker();
                                final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                                if (image != null) {
                                  setStateDialog(() {
                                    selectedFile = image;
                                  });
                                }
                              },
                              icon: const Icon(Icons.upload_file),
                              label: Text(selectedFile != null ? 'Sheet Selected' : 'Upload Closing Sheet'),
                            ),
                          ),
                          if (selectedFile != null) ...[
                            SizedBox(width: 8.w),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => setStateDialog(() => selectedFile = null),
                            )
                          ]
                        ],
                      ),
                      if (isUploading) ...[
                        SizedBox(height: 12.h),
                        const CircularProgressIndicator(color: Color(0xFF10B981)),
                      ]
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF6B7280))),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setStateDialog(() {
                            isUploading = true;
                          });

                          try {
                            final provider = context.read<PettyCashProvider>();
                            String? closingSheetUrl;

                            if (selectedFile != null) {
                              closingSheetUrl = await provider.uploadClosingSheet(selectedFile!, session.id);
                            }

                            final double actualCash = double.parse(cashController.text);
                            final double stc = double.tryParse(stcController.text) ?? 0.0;
                            final double other = double.tryParse(otherController.text) ?? 0.0;
                            final double closingBal = actualCash + stc + other;

                            final closed = session.copyWith(
                              closedBy: 'ADMIN',
                              closingBalance: closingBal,
                              cashInHand: actualCash,
                              stcPayBalance: stc,
                              otherDigitalBalance: other,
                              closingSheetUrl: closingSheetUrl,
                              notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                            );

                            await provider.closeSession(closed);
                            if (context.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to close session: $e')),
                            );
                          } finally {
                            setStateDialog(() {
                              isUploading = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Close Session', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fundAccountProvider = context.watch<FundAccountProvider>();
    final pettyCashProvider = context.watch<PettyCashProvider>();

    final pcAccounts = fundAccountProvider.accounts.where((a) => a.type == FundAccountType.pettyCash).toList();
    final selectedAccount = _selectedAccountId != null
        ? fundAccountProvider.getAccountById(_selectedAccountId!)
        : null;

    final hasOpen = pettyCashProvider.hasOpenSession;
    final currentSession = pettyCashProvider.currentSession;
    final sessions = pettyCashProvider.sessions;

    return Row(
      children: [
        // Left Panel — Sessions History List
        Expanded(
          flex: 2,
          child: Container(
            color: const Color(0xFFF9FAFB),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Petty Cash Accounts',
                        style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
                      ),
                      SizedBox(height: 10.h),
                      DropdownButtonFormField<String>(
                        value: _selectedAccountId,
                        items: pcAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.code})'))).toList(),
                        onChanged: _onAccountChanged,
                        style: GoogleFonts.inter(fontSize: 13.sp, color: Colors.black),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: pettyCashProvider.isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                      : sessions.isEmpty
                          ? Center(
                              child: Text(
                                'No daily sessions recorded',
                                style: GoogleFonts.inter(color: const Color(0xFF9CA3AF), fontSize: 13.sp),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              itemCount: sessions.length,
                              itemBuilder: (ctx, index) {
                                final s = sessions[index];
                                final isVerified = s.status == PettyCashSessionStatus.verified;
                                return Card(
                                  margin: EdgeInsets.only(bottom: 12.h),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                    side: BorderSide(
                                      color: s.discrepancy != null && s.discrepancy != 0
                                          ? Colors.red.shade200
                                          : const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                    title: Text(
                                      DateFormat('dd MMMM yyyy').format(s.date),
                                      style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      'Closing: ${s.closingBalance.toStringAsFixed(2)} SAR\nStatus: ${s.status.displayName}',
                                      style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF6B7280)),
                                    ),
                                    trailing: s.discrepancy != null && s.discrepancy != 0
                                        ? Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF1F2),
                                              borderRadius: BorderRadius.circular(6.r),
                                            ),
                                            child: Text(
                                              'Diff: ${s.discrepancy!.toStringAsFixed(2)}',
                                              style: GoogleFonts.inter(fontSize: 10.sp, fontWeight: FontWeight.w600, color: Colors.red),
                                            ),
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
        // Divider
        const VerticalDivider(width: 1, color: Color(0xFFE5E7EB)),
        // Right Panel — Active Session Control
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.white,
            padding: EdgeInsets.all(24.w),
            child: selectedAccount == null
                ? Center(
                    child: Text('Select petty cash account to begin'),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Closing Status',
                        style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 24.h),
                      if (!hasOpen) ...[
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.lock_clock_outlined, size: 54.sp, color: const Color(0xFF9CA3AF)),
                              SizedBox(height: 16.h),
                              Text(
                                'Petty Cash is Closed',
                                style: GoogleFonts.inter(fontSize: 15.sp, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'Please open daily session to record transactions.',
                                style: GoogleFonts.inter(fontSize: 12.sp, color: const Color(0xFF6B7280)),
                              ),
                              SizedBox(height: 20.h),
                              ElevatedButton.icon(
                                onPressed: () => _showOpenSessionDialog(context, selectedAccount),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Open Daily Session'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.check_circle, color: const Color(0xFF16A34A), size: 20.sp),
                                  SizedBox(width: 10.w),
                                  Text(
                                    'Daily Session is OPEN',
                                    style: GoogleFonts.inter(fontSize: 14.sp, fontWeight: FontWeight.w700, color: const Color(0xFF166534)),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatDetail('Opened By', currentSession!.openedBy ?? 'Admin'),
                                  _buildStatDetail('Open Date', DateFormat('dd MMM yyyy').format(currentSession.date)),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatDetail('Opening Balance', '${currentSession.openingBalance.toStringAsFixed(2)} SAR'),
                                  _buildStatDetail('Expected Balance', '${currentSession.expectedClosingBalance.toStringAsFixed(2)} SAR'),
                                ],
                              ),
                              SizedBox(height: 20.h),
                              ElevatedButton.icon(
                                onPressed: () => _showCloseSessionDialog(context, currentSession),
                                icon: const Icon(Icons.close),
                                label: const Text('Record Daily Closing'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11.sp, color: const Color(0xFF6B7280))),
        SizedBox(height: 2.h),
        Text(value, style: GoogleFonts.inter(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
      ],
    );
  }

  Widget _buildDialogTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
        ),
        SizedBox(height: 6.h),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: GoogleFonts.inter(fontSize: 13.sp),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
          ),
        ),
      ],
    );
  }
}
