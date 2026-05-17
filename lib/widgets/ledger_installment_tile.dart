import 'package:flutter/material.dart';
import '../utils/ledger_calculator.dart';

class LedgerInstallmentTile extends StatelessWidget {
  final DateTime date;
  final int amount;
  final int interestPaid;
  final int principalPaid;
  final int principalApplied;
  final int overpayment;
  final int remainingAfter;
  final VoidCallback? onDelete;

  const LedgerInstallmentTile({
    super.key,
    required this.date,
    required this.amount,
    required this.interestPaid,
    required this.principalPaid,
    this.principalApplied = 0,
    this.overpayment = 0,
    required this.remainingAfter,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOverpay = overpayment > 0 || remainingAfter < 0;
    final borderColor = isOverpay ? Colors.deepOrange.shade300 : Colors.grey.shade200;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: isOverpay ? Colors.orange.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: isOverpay ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isOverpay ? Colors.deepOrange : const Color(0xFF1E3A8A))
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isOverpay ? Icons.warning_amber_rounded : Icons.payments,
                color: isOverpay ? Colors.deepOrange : const Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        LedgerMoneyFormat.rupees(amount),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _chip('Interest', LedgerMoneyFormat.rupees(interestPaid), Colors.orange),
                      _chip(
                        'To principal',
                        LedgerMoneyFormat.rupees(
                          principalApplied > 0 ? principalApplied : principalPaid,
                        ),
                        Colors.green,
                      ),
                      if (overpayment > 0)
                        _chip(
                          'Excess paid',
                          LedgerMoneyFormat.rupees(overpayment),
                          Colors.deepOrange,
                        ),
                      _chip(
                        'Balance after',
                        LedgerMoneyFormat.rupees(remainingAfter),
                        remainingAfter < 0 ? Colors.red : Colors.blueGrey,
                      ),
                    ],
                  ),
                  if (isOverpay)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'This payment exceeded the outstanding principal.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.deepOrange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
                tooltip: 'Delete installment',
              ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
