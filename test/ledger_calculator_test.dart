import 'package:flutter_test/flutter_test.dart';
import 'package:property_manager/utils/ledger_calculator.dart';

void main() {
  test('interest is paid before principal', () {
    final split = LedgerCalculator.calculateSplit(
      remainingPrincipal: 20000,
      monthlyRatePercent: 8,
      paymentAmount: 5000,
    );

    expect(split.interestDue, 1600);
    expect(split.interestPaid, 1600);
    expect(split.principalPaid, 3400);
    expect(split.remainingAfter, 16600);
  });

  test('overpayment produces negative balance', () {
    final replay = LedgerCalculator.replay(
      originalPrincipal: 20000,
      monthlyRatePercent: 8,
      payments: [
        LedgerPaymentInput(
          date: DateTime(2026, 3, 6),
          amount: 20000,
        ),
        LedgerPaymentInput(
          date: DateTime(2026, 3, 22),
          amount: 100000,
        ),
      ],
    );

    expect(replay.remainingPrincipal, lessThan(0));
    expect(replay.overpaidAmount, greaterThan(0));
  });
}
