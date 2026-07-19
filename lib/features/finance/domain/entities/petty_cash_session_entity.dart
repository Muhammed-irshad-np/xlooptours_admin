import 'package:equatable/equatable.dart';

/// Status of a petty cash session for a given day.
enum PettyCashSessionStatus {
  open,
  closed,
  verified;

  String get displayName {
    switch (this) {
      case PettyCashSessionStatus.open:
        return 'Open';
      case PettyCashSessionStatus.closed:
        return 'Closed';
      case PettyCashSessionStatus.verified:
        return 'Verified';
    }
  }
}

/// Represents a daily petty cash session (open/close cycle).
///
/// Each day, a coordinator opens a session (recording opening balance),
/// and closes it at end of day (recording what's in hand). The admin
/// can then verify the closing and flag any discrepancies.
class PettyCashSessionEntity extends Equatable {
  final String id;
  final String fundAccountId;
  final DateTime date;
  final String? openedBy;
  final String? closedBy;
  final double openingBalance;

  /// Total expenses recorded against this account for the day.
  final double totalExpenses;

  /// Total deposits made into this account during the day.
  final double deposits;

  /// Actual closing balance reported by the coordinator.
  final double closingBalance;

  /// Breakdown of closing balance by payment method.
  final double cashInHand;
  final double? stcPayBalance;
  final double? otherDigitalBalance;

  /// URL of the uploaded closing sheet (PDF/image).
  final String? closingSheetUrl;

  final PettyCashSessionStatus status;
  final String? verifiedBy;
  final DateTime? verifiedAt;

  /// Difference between expected and actual closing balance.
  /// Positive = surplus, Negative = shortfall.
  final double? discrepancy;

  final String? notes;
  final DateTime createdAt;

  const PettyCashSessionEntity({
    required this.id,
    required this.fundAccountId,
    required this.date,
    this.openedBy,
    this.closedBy,
    this.openingBalance = 0.0,
    this.totalExpenses = 0.0,
    this.deposits = 0.0,
    this.closingBalance = 0.0,
    this.cashInHand = 0.0,
    this.stcPayBalance,
    this.otherDigitalBalance,
    this.closingSheetUrl,
    this.status = PettyCashSessionStatus.open,
    this.verifiedBy,
    this.verifiedAt,
    this.discrepancy,
    this.notes,
    required this.createdAt,
  });

  /// Expected closing balance = opening + deposits - expenses.
  double get expectedClosingBalance =>
      openingBalance + deposits - totalExpenses;

  factory PettyCashSessionEntity.empty() {
    return PettyCashSessionEntity(
      id: '',
      fundAccountId: '',
      date: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  PettyCashSessionEntity copyWith({
    String? id,
    String? fundAccountId,
    DateTime? date,
    String? openedBy,
    String? closedBy,
    double? openingBalance,
    double? totalExpenses,
    double? deposits,
    double? closingBalance,
    double? cashInHand,
    double? stcPayBalance,
    double? otherDigitalBalance,
    String? closingSheetUrl,
    PettyCashSessionStatus? status,
    String? verifiedBy,
    DateTime? verifiedAt,
    double? discrepancy,
    String? notes,
    DateTime? createdAt,
    bool clearOpenedBy = false,
    bool clearClosedBy = false,
    bool clearStcPayBalance = false,
    bool clearOtherDigitalBalance = false,
    bool clearClosingSheetUrl = false,
    bool clearVerifiedBy = false,
    bool clearVerifiedAt = false,
    bool clearDiscrepancy = false,
    bool clearNotes = false,
  }) {
    return PettyCashSessionEntity(
      id: id ?? this.id,
      fundAccountId: fundAccountId ?? this.fundAccountId,
      date: date ?? this.date,
      openedBy: clearOpenedBy ? null : (openedBy ?? this.openedBy),
      closedBy: clearClosedBy ? null : (closedBy ?? this.closedBy),
      openingBalance: openingBalance ?? this.openingBalance,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      deposits: deposits ?? this.deposits,
      closingBalance: closingBalance ?? this.closingBalance,
      cashInHand: cashInHand ?? this.cashInHand,
      stcPayBalance: clearStcPayBalance
          ? null
          : (stcPayBalance ?? this.stcPayBalance),
      otherDigitalBalance: clearOtherDigitalBalance
          ? null
          : (otherDigitalBalance ?? this.otherDigitalBalance),
      closingSheetUrl: clearClosingSheetUrl
          ? null
          : (closingSheetUrl ?? this.closingSheetUrl),
      status: status ?? this.status,
      verifiedBy:
          clearVerifiedBy ? null : (verifiedBy ?? this.verifiedBy),
      verifiedAt:
          clearVerifiedAt ? null : (verifiedAt ?? this.verifiedAt),
      discrepancy:
          clearDiscrepancy ? null : (discrepancy ?? this.discrepancy),
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fundAccountId,
        date,
        openedBy,
        closedBy,
        openingBalance,
        totalExpenses,
        deposits,
        closingBalance,
        cashInHand,
        stcPayBalance,
        otherDigitalBalance,
        closingSheetUrl,
        status,
        verifiedBy,
        verifiedAt,
        discrepancy,
        notes,
        createdAt,
      ];
}
