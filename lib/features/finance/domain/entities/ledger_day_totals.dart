/// Sum of ledger activity for one fund account on one calendar day.
class LedgerDayTotals {
  final double cashDeposits;
  final double stcPayDeposits;
  final double cashExpenses;
  final double stcPayExpenses;
  final double otherIn;
  final double otherOut;

  const LedgerDayTotals({
    this.cashDeposits = 0,
    this.stcPayDeposits = 0,
    this.cashExpenses = 0,
    this.stcPayExpenses = 0,
    this.otherIn = 0,
    this.otherOut = 0,
  });

  double get totalIn => cashDeposits + stcPayDeposits + otherIn;
  double get totalOut => cashExpenses + stcPayExpenses + otherOut;
}
