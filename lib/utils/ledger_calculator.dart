/// Shared ledger math: monthly interest on remaining principal,
/// interest paid first, then principal. Balance may go negative (overpaid).
class InstallmentSplit {
  final int amount;
  final int remainingBefore;
  final int interestDue;
  final int interestPaid;
  final int principalPaid;
  final int principalApplied;
  final int overpayment;
  final int remainingAfter;

  const InstallmentSplit({
    required this.amount,
    required this.remainingBefore,
    required this.interestDue,
    required this.interestPaid,
    required this.principalPaid,
    required this.principalApplied,
    required this.overpayment,
    required this.remainingAfter,
  });

  bool get causesOverpayment => remainingAfter < 0 || overpayment > 0;
}

class LedgerReplayResult {
  final List<InstallmentSplit> splits;
  final int originalPrincipal;
  final int remainingPrincipal;
  final int totalPaid;
  final int totalInterestPaid;
  final int totalPrincipalPaid;

  const LedgerReplayResult({
    required this.splits,
    required this.originalPrincipal,
    required this.remainingPrincipal,
    required this.totalPaid,
    required this.totalInterestPaid,
    required this.totalPrincipalPaid,
  });

  /// Amount paid beyond the original principal (balance below zero).
  int get overpaidAmount =>
      remainingPrincipal < 0 ? -remainingPrincipal : 0;

  bool get isOverpaid => remainingPrincipal < 0;

  bool get isFullyRepaid => remainingPrincipal == 0;

  int get principalRepaidTowardLoan {
    if (remainingPrincipal >= 0) {
      return originalPrincipal - remainingPrincipal;
    }
    return originalPrincipal;
  }
}

class LedgerPaymentInput {
  final DateTime date;
  final int amount;

  const LedgerPaymentInput({required this.date, required this.amount});
}

class LedgerMoneyFormat {
  static String rupees(int value) {
    if (value < 0) return '-₹ ${-value}';
    return '₹ $value';
  }

  static String balanceLabel(int remainingPrincipal) {
    if (remainingPrincipal < 0) {
      return 'Overpaid ${rupees(-remainingPrincipal)}';
    }
    if (remainingPrincipal == 0) return 'Fully repaid';
    return 'Balance ${rupees(remainingPrincipal)}';
  }
}

class LedgerCalculator {
  /// Monthly interest on positive remaining principal only.
  static int monthlyInterestDue(int remainingPrincipal, int monthlyRatePercent) {
    if (remainingPrincipal <= 0 || monthlyRatePercent <= 0) return 0;
    return ((remainingPrincipal * monthlyRatePercent) / 100).round();
  }

  /// Interest first, then principal; balance can be negative.
  static InstallmentSplit calculateSplit({
    required int remainingPrincipal,
    required int monthlyRatePercent,
    required int paymentAmount,
  }) {
    final remainingBefore = remainingPrincipal;
    final interestDue = monthlyInterestDue(remainingPrincipal, monthlyRatePercent);

    final int interestPaid;
    final int principalPaid;

    if (paymentAmount >= interestDue) {
      interestPaid = interestDue;
      principalPaid = paymentAmount - interestDue;
    } else {
      interestPaid = paymentAmount;
      principalPaid = 0;
    }

    final remainingAfter = remainingPrincipal - principalPaid;

    final principalApplied = remainingBefore > 0
        ? principalPaid.clamp(0, remainingBefore)
        : 0;

    final overpayment = remainingAfter < 0 ? -remainingAfter : 0;

    return InstallmentSplit(
      amount: paymentAmount,
      remainingBefore: remainingBefore,
      interestDue: interestDue,
      interestPaid: interestPaid,
      principalPaid: principalPaid,
      principalApplied: principalApplied,
      overpayment: overpayment,
      remainingAfter: remainingAfter,
    );
  }

  static LedgerReplayResult replay({
    required int originalPrincipal,
    required int monthlyRatePercent,
    required List<LedgerPaymentInput> payments,
  }) {
    final sorted = List<LedgerPaymentInput>.from(payments)
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.amount.compareTo(b.amount);
      });

    var remaining = originalPrincipal;
    var totalPaid = 0;
    var totalInterest = 0;
    var totalPrincipal = 0;
    final splits = <InstallmentSplit>[];

    for (final payment in sorted) {
      final split = calculateSplit(
        remainingPrincipal: remaining,
        monthlyRatePercent: monthlyRatePercent,
        paymentAmount: payment.amount,
      );
      splits.add(split);
      remaining = split.remainingAfter;
      totalPaid += payment.amount;
      totalInterest += split.interestPaid;
      totalPrincipal += split.principalPaid;
    }

    return LedgerReplayResult(
      splits: splits,
      originalPrincipal: originalPrincipal,
      remainingPrincipal: remaining,
      totalPaid: totalPaid,
      totalInterestPaid: totalInterest,
      totalPrincipalPaid: totalPrincipal,
    );
  }
}
