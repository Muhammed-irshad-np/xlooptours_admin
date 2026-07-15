import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:xloop_invoice/features/finance/domain/entities/fund_transaction_entity.dart';

/// Displays a timeline of fund transactions for an account.
class TransactionTimeline extends StatelessWidget {
  final List<FundTransactionEntity> transactions;

  const TransactionTimeline({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40.w),
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 48.sp, color: const Color(0xFFD1D5DB)),
              SizedBox(height: 12.h),
              Text(
                'No transactions yet',
                style: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF9CA3AF)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return _TransactionTile(transaction: tx, isLast: index == transactions.length - 1);
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final FundTransactionEntity transaction;
  final bool isLast;

  const _TransactionTile({required this.transaction, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.type == FundTransactionType.deposit ||
        (transaction.type == FundTransactionType.adjustment && transaction.amount > 0);
    final config = isCredit
        ? _TxConfig(
            icon: Icons.arrow_downward_rounded,
            color: const Color(0xFF22C55E),
            prefix: '+',
          )
        : _TxConfig(
            icon: Icons.arrow_upward_rounded,
            color: const Color(0xFFEF4444),
            prefix: '-',
          );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot and line
          SizedBox(
            width: 32.w,
            child: Column(
              children: [
                Container(
                  width: 10.w,
                  height: 10.w,
                  decoration: BoxDecoration(
                    color: config.color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: config.color, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: const Color(0xFFE5E7EB),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.description,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${DateFormat('dd MMM yyyy, hh:mm a').format(transaction.date)} • ${transaction.performedBy}',
                          style: GoogleFonts.inter(
                            fontSize: 10.sp,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${config.prefix}${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: config.color,
                        ),
                      ),
                      Text(
                        'Bal: ${transaction.balanceAfter.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 10.sp,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TxConfig {
  final IconData icon;
  final Color color;
  final String prefix;
  _TxConfig({required this.icon, required this.color, required this.prefix});
}
