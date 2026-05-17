import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/ledger_service.dart';
import '../../utils/ledger_calculator.dart';

class AddInstallmentScreen extends StatefulWidget {
  final String loanId;
  final String ledgerType;
  final String personName;
  final int originalPrincipal;
  final int interestRate;

  const AddInstallmentScreen({
    super.key,
    required this.loanId,
    required this.ledgerType,
    required this.personName,
    required this.originalPrincipal,
    required this.interestRate,
  });

  @override
  State<AddInstallmentScreen> createState() => _AddInstallmentScreenState();
}

class _AddInstallmentScreenState extends State<AddInstallmentScreen> {
  final LedgerService _ledgerService = LedgerService();
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  DateTime paymentDate = DateTime.now();
  bool loading = false;
  List<LedgerPaymentInput> _existing = [];

  @override
  void initState() {
    super.initState();
    _loadExisting();
    amountController.addListener(() => setState(() {}));
  }

  Future<void> _loadExisting() async {
    final ref = _ledgerService.loanRef(
      ledgerType: widget.ledgerType,
      loanId: widget.loanId,
    );
    final snap = await ref.collection('installments').orderBy('date').get();

    if (!mounted) return;
    setState(() {
      _existing = snap.docs.map((doc) {
        final data = doc.data();
        final ts = data['date'];
        final date = ts is Timestamp ? ts.toDate() : DateTime.now();
        return LedgerPaymentInput(
          date: date,
          amount: _asInt(data['amount']),
        );
      }).toList();
    });
  }

  LedgerReplayResult? get _previewReplay {
    final amount = int.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) return null;

    return LedgerCalculator.replay(
      originalPrincipal: widget.originalPrincipal,
      monthlyRatePercent: widget.interestRate,
      payments: [
        ..._existing,
        LedgerPaymentInput(date: paymentDate, amount: amount),
      ],
    );
  }

  InstallmentSplit? get _previewSplit {
    final replay = _previewReplay;
    if (replay == null || replay.splits.isEmpty) return null;
    return replay.splits.last;
  }

  Future<void> saveInstallment() async {
    final amount = int.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid payment amount');
      return;
    }

    final replay = _previewReplay;
    if (replay != null && replay.isOverpaid) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: Colors.deepOrange.shade800),
          title: const Text('Overpayment warning'),
          content: Text(
            'This payment will exceed the loan principal.\n\n'
            'Overpaid amount: ${LedgerMoneyFormat.rupees(replay.overpaidAmount)}\n'
            'Balance after: ${LedgerMoneyFormat.rupees(replay.remainingPrincipal)}\n\n'
            'The negative balance will be saved so you can track excess payments.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => loading = true);

    try {
      final result = await _ledgerService.addInstallment(
        ledgerType: widget.ledgerType,
        loanId: widget.loanId,
        amount: amount,
        date: paymentDate,
        note: noteController.text.trim(),
      );

      if (!mounted) return;

      if (result.isOverpaid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.deepOrange.shade800,
            duration: const Duration(seconds: 5),
            content: Text(
              'Saved with overpayment of '
              '${LedgerMoneyFormat.rupees(result.overpaidAmount)}. '
              'Balance: ${LedgerMoneyFormat.rupees(result.remainingPrincipal)}.',
            ),
          ),
        );
      }

      Navigator.pop(context, result);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Failed to save payment');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final split = _previewSplit;
    final replay = _previewReplay;

    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.personName.isEmpty ? 'Payment' : widget.personName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Loan ${LedgerMoneyFormat.rupees(widget.originalPrincipal)} · '
              '${widget.interestRate}% monthly interest',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Payments are sorted by date. Each time: monthly interest on '
                'current balance is paid first, then principal. If extra is paid, '
                'balance goes negative (overpaid) and is shown clearly.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Payment amount',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                'Date: ${paymentDate.day}/${paymentDate.month}/${paymentDate.year}',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: paymentDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => paymentDate = picked);
              },
            ),
            if (replay != null && replay.isOverpaid) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepOrange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.deepOrange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Will overpay by ${LedgerMoneyFormat.rupees(replay.overpaidAmount)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (split != null) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: split.causesOverpayment
                        ? Colors.deepOrange
                        : Colors.grey.shade300,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'After this payment (preview)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _previewRow(
                        'Balance before',
                        LedgerMoneyFormat.rupees(split.remainingBefore),
                      ),
                      _previewRow(
                        'Interest due (monthly)',
                        LedgerMoneyFormat.rupees(split.interestDue),
                      ),
                      _previewRow(
                        'Interest paid',
                        LedgerMoneyFormat.rupees(split.interestPaid),
                      ),
                      _previewRow(
                        'Toward principal',
                        LedgerMoneyFormat.rupees(split.principalApplied),
                      ),
                      if (split.overpayment > 0)
                        _previewRow(
                          'Excess (overpaid)',
                          LedgerMoneyFormat.rupees(split.overpayment),
                          highlight: true,
                        ),
                      _previewRow(
                        'Balance after',
                        LedgerMoneyFormat.rupees(split.remainingAfter),
                        bold: true,
                        negative: split.remainingAfter < 0,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : saveInstallment,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Payment', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewRow(
    String label,
    String value, {
    bool bold = false,
    bool highlight = false,
    bool negative = false,
  }) {
    Color? color;
    if (negative) color = Colors.red;
    if (highlight) color = Colors.deepOrange;
    if (bold && color == null) color = const Color(0xFF1E3A8A);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold || highlight ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
