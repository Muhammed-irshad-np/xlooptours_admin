import '../../domain/entities/fund_transaction_entity.dart';

class FundTransactionModel extends FundTransactionEntity {
  const FundTransactionModel({
    required super.id,
    required super.fundAccountId,
    required super.type,
    required super.amount,
    super.amountMinor,
    required super.currency,
    required super.description,
    super.referenceExpenseId,
    super.transferToAccountId,
    super.transferPairId,
    super.reversesTransactionId,
    required super.performedBy,
    super.performedByUserId,
    required super.date,
    required super.createdAt,
    required super.balanceBefore,
    required super.balanceAfter,
    super.bucket = FundBucket.total,
    super.isReversed = false,
    super.auditNote,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fundAccountId': fundAccountId,
      'type': type.name,
      'amount': amount,
      'amountMinor': amountMinor ?? (amount * 100).round(),
      'currency': currency,
      'description': description,
      'referenceExpenseId': referenceExpenseId,
      'transferToAccountId': transferToAccountId,
      'transferPairId': transferPairId,
      'reversesTransactionId': reversesTransactionId,
      'performedBy': performedBy,
      'performedByUserId': performedByUserId,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'bucket': bucket.name,
      'isReversed': isReversed,
      'auditNote': auditNote,
    };
  }

  factory FundTransactionModel.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    return FundTransactionModel(
      id: json['id'] as String,
      fundAccountId: json['fundAccountId'] as String? ?? '',
      type: _parseType(json['type'] as String?),
      amount: amount,
      amountMinor: (json['amountMinor'] as num?)?.toInt() ??
          (amount * 100).round(),
      currency: json['currency'] as String? ?? 'SAR',
      description: json['description'] as String? ?? '',
      referenceExpenseId: json['referenceExpenseId'] as String?,
      transferToAccountId: json['transferToAccountId'] as String?,
      transferPairId: json['transferPairId'] as String?,
      reversesTransactionId: json['reversesTransactionId'] as String?,
      performedBy: json['performedBy'] as String? ?? '',
      performedByUserId: json['performedByUserId'] as String?,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      balanceBefore: (json['balanceBefore'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0.0,
      bucket: _parseBucket(json['bucket'] as String?),
      isReversed: json['isReversed'] as bool? ?? false,
      auditNote: json['auditNote'] as String?,
    );
  }

  factory FundTransactionModel.fromEntity(FundTransactionEntity entity) {
    return FundTransactionModel(
      id: entity.id,
      fundAccountId: entity.fundAccountId,
      type: entity.type,
      amount: entity.amount,
      amountMinor: entity.amountMinor ?? (entity.amount * 100).round(),
      currency: entity.currency,
      description: entity.description,
      referenceExpenseId: entity.referenceExpenseId,
      transferToAccountId: entity.transferToAccountId,
      transferPairId: entity.transferPairId,
      reversesTransactionId: entity.reversesTransactionId,
      performedBy: entity.performedBy,
      performedByUserId: entity.performedByUserId,
      date: entity.date,
      createdAt: entity.createdAt,
      balanceBefore: entity.balanceBefore,
      balanceAfter: entity.balanceAfter,
      bucket: entity.bucket,
      isReversed: entity.isReversed,
      auditNote: entity.auditNote,
    );
  }

  static FundTransactionType _parseType(String? type) {
    if (type == null) return FundTransactionType.deposit;
    return FundTransactionType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => FundTransactionType.deposit,
    );
  }

  static FundBucket _parseBucket(String? bucket) {
    if (bucket == null) return FundBucket.total;
    return FundBucket.values.firstWhere(
      (e) => e.name == bucket,
      orElse: () => FundBucket.total,
    );
  }
}
