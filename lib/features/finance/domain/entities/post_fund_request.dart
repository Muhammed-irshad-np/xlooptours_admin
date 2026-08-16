import 'fund_transaction_entity.dart';

/// Request to post money. Amount is always positive; [credit] controls direction.
/// Balances are computed only inside a Firestore transaction — never trust UI.
class PostFundRequest {
  final String fundAccountId;
  final FundTransactionType type;
  final double amountMajor;
  final String currency;
  final String description;
  final String performedBy;
  final String? performedByUserId;
  final String? referenceExpenseId;
  final String? transferToAccountId;
  final String? transferPairId;
  final String? reversesTransactionId;
  final FundBucket bucket;
  final bool credit;
  final double? cashDeltaMajor;
  final double? stcPayDeltaMajor;
  final String? auditNote;
  final DateTime? date;

  const PostFundRequest({
    required this.fundAccountId,
    required this.type,
    required this.amountMajor,
    required this.currency,
    required this.description,
    required this.performedBy,
    this.performedByUserId,
    this.referenceExpenseId,
    this.transferToAccountId,
    this.transferPairId,
    this.reversesTransactionId,
    this.bucket = FundBucket.total,
    required this.credit,
    this.cashDeltaMajor,
    this.stcPayDeltaMajor,
    this.auditNote,
    this.date,
  });
}
