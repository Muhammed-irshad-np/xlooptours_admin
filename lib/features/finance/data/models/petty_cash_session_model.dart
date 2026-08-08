import '../../domain/entities/petty_cash_session_entity.dart';

/// Data model for [PettyCashSessionEntity] with Firestore serialization.
class PettyCashSessionModel extends PettyCashSessionEntity {
  const PettyCashSessionModel({
    required super.id,
    required super.fundAccountId,
    required super.date,
    super.openedBy,
    super.closedBy,
    super.openingCashBalance = 0.0,
    super.openingStcPayBalance = 0.0,
    super.cashDeposits = 0.0,
    super.stcPayDeposits = 0.0,
    super.cashExpenses = 0.0,
    super.stcPayExpenses = 0.0,
    super.closingBalance = 0.0,
    super.cashInHand = 0.0,
    super.stcPayBalance,
    super.otherDigitalBalance,
    super.closingSheetUrl,
    super.status = PettyCashSessionStatus.open,
    super.verifiedBy,
    super.verifiedAt,
    super.discrepancy,
    super.notes,
    required super.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fundAccountId': fundAccountId,
      'date': date.toIso8601String(),
      'openedBy': openedBy,
      'closedBy': closedBy,
      'openingCashBalance': openingCashBalance,
      'openingStcPayBalance': openingStcPayBalance,
      'cashDeposits': cashDeposits,
      'stcPayDeposits': stcPayDeposits,
      'cashExpenses': cashExpenses,
      'stcPayExpenses': stcPayExpenses,
      'closingBalance': closingBalance,
      'cashInHand': cashInHand,
      'stcPayBalance': stcPayBalance,
      'otherDigitalBalance': otherDigitalBalance,
      'closingSheetUrl': closingSheetUrl,
      'status': status.name,
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'discrepancy': discrepancy,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PettyCashSessionModel.fromJson(Map<String, dynamic> json) {
    final legacyOpening = (json['openingBalance'] as num?)?.toDouble() ?? 0.0;
    final legacyDeposits = (json['deposits'] as num?)?.toDouble() ?? 0.0;
    final legacyExpenses = (json['totalExpenses'] as num?)?.toDouble() ?? 0.0;

    return PettyCashSessionModel(
      id: json['id'] as String,
      fundAccountId: json['fundAccountId'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      openedBy: json['openedBy'] as String?,
      closedBy: json['closedBy'] as String?,
      openingCashBalance: (json['openingCashBalance'] as num?)?.toDouble() ?? legacyOpening,
      openingStcPayBalance: (json['openingStcPayBalance'] as num?)?.toDouble() ?? 0.0,
      cashDeposits: (json['cashDeposits'] as num?)?.toDouble() ?? legacyDeposits,
      stcPayDeposits: (json['stcPayDeposits'] as num?)?.toDouble() ?? 0.0,
      cashExpenses: (json['cashExpenses'] as num?)?.toDouble() ?? legacyExpenses,
      stcPayExpenses: (json['stcPayExpenses'] as num?)?.toDouble() ?? 0.0,
      closingBalance: (json['closingBalance'] as num?)?.toDouble() ?? 0.0,
      cashInHand: (json['cashInHand'] as num?)?.toDouble() ?? 0.0,
      stcPayBalance: (json['stcPayBalance'] as num?)?.toDouble(),
      otherDigitalBalance:
          (json['otherDigitalBalance'] as num?)?.toDouble(),
      closingSheetUrl: json['closingSheetUrl'] as String?,
      status: _parseStatus(json['status'] as String?),
      verifiedBy: json['verifiedBy'] as String?,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'] as String)
          : null,
      discrepancy: (json['discrepancy'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  factory PettyCashSessionModel.fromEntity(PettyCashSessionEntity entity) {
    return PettyCashSessionModel(
      id: entity.id,
      fundAccountId: entity.fundAccountId,
      date: entity.date,
      openedBy: entity.openedBy,
      closedBy: entity.closedBy,
      openingCashBalance: entity.openingCashBalance,
      openingStcPayBalance: entity.openingStcPayBalance,
      cashDeposits: entity.cashDeposits,
      stcPayDeposits: entity.stcPayDeposits,
      cashExpenses: entity.cashExpenses,
      stcPayExpenses: entity.stcPayExpenses,
      closingBalance: entity.closingBalance,
      cashInHand: entity.cashInHand,
      stcPayBalance: entity.stcPayBalance,
      otherDigitalBalance: entity.otherDigitalBalance,
      closingSheetUrl: entity.closingSheetUrl,
      status: entity.status,
      verifiedBy: entity.verifiedBy,
      verifiedAt: entity.verifiedAt,
      discrepancy: entity.discrepancy,
      notes: entity.notes,
      createdAt: entity.createdAt,
    );
  }

  static PettyCashSessionStatus _parseStatus(String? status) {
    if (status == null) return PettyCashSessionStatus.open;
    return PettyCashSessionStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => PettyCashSessionStatus.open,
    );
  }
}
