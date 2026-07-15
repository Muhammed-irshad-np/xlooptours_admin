import '../../domain/entities/fund_transaction_entity.dart';

/// Data model for [FundTransactionEntity] with Firestore serialization.
class FundTransactionModel extends FundTransactionEntity {
  const FundTransactionModel({
    required super.id,
    required super.fundAccountId,
    required super.type,
    required super.amount,
    required super.currency,
    required super.description,
    super.referenceExpenseId,
    super.transferToAccountId,
    required super.performedBy,
    required super.date,
    required super.createdAt,
    required super.balanceBefore,
    required super.balanceAfter,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fundAccountId': fundAccountId,
      'type': type.name,
      'amount': amount,
      'currency': currency,
      'description': description,
      'referenceExpenseId': referenceExpenseId,
      'transferToAccountId': transferToAccountId,
      'performedBy': performedBy,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
    };
  }

  factory FundTransactionModel.fromJson(Map<String, dynamic> json) {
    return FundTransactionModel(
      id: json['id'] as String,
      fundAccountId: json['fundAccountId'] as String? ?? '',
      type: _parseType(json['type'] as String?),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'SAR',
      description: json['description'] as String? ?? '',
      referenceExpenseId: json['referenceExpenseId'] as String?,
      transferToAccountId: json['transferToAccountId'] as String?,
      performedBy: json['performedBy'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      balanceBefore: (json['balanceBefore'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory FundTransactionModel.fromEntity(FundTransactionEntity entity) {
    return FundTransactionModel(
      id: entity.id,
      fundAccountId: entity.fundAccountId,
      type: entity.type,
      amount: entity.amount,
      currency: entity.currency,
      description: entity.description,
      referenceExpenseId: entity.referenceExpenseId,
      transferToAccountId: entity.transferToAccountId,
      performedBy: entity.performedBy,
      date: entity.date,
      createdAt: entity.createdAt,
      balanceBefore: entity.balanceBefore,
      balanceAfter: entity.balanceAfter,
    );
  }

  static FundTransactionType _parseType(String? type) {
    if (type == null) return FundTransactionType.deposit;
    return FundTransactionType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => FundTransactionType.deposit,
    );
  }
}
