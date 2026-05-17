import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_installment_screen.dart';
import '../../services/ledger_service.dart';
import '../../services/pdf_service.dart';
import '../../utils/ledger_calculator.dart';
import '../../widgets/breadcrumb.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/ledger_installment_tile.dart';

class LedgerDetailScreen extends StatefulWidget {
  final String loanId;
  final String ledgerType;
  final String title;
  final String listLabel;

  const LedgerDetailScreen({
    super.key,
    required this.loanId,
    required this.ledgerType,
    required this.title,
    required this.listLabel,
  });

  @override
  State<LedgerDetailScreen> createState() => _LedgerDetailScreenState();
}

class _LedgerDetailScreenState extends State<LedgerDetailScreen> {
  final LedgerService _ledgerService = LedgerService();
  bool _syncing = true;
  bool _overpaidAlertShown = false;

  @override
  void initState() {
    super.initState();
    _syncBalances(notifyOverpay: true);
  }

  Future<void> _syncBalances({bool notifyOverpay = false}) async {
    try {
      final replay = await _ledgerService.recalculateLoan(
        ledgerType: widget.ledgerType,
        loanId: widget.loanId,
      );

      if (!mounted) return;

      if (notifyOverpay && replay.isOverpaid && !_overpaidAlertShown) {
        _overpaidAlertShown = true;
        _showOverpaymentAlert(replay.overpaidAmount, replay.remainingPrincipal);
      }
    } catch (_) {
      // Show stale data if sync fails.
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _showOverpaymentAlert(int overpaidAmount, int balance) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.deepOrange.shade800,
        duration: const Duration(seconds: 6),
        content: Text(
          'Overpayment: ${LedgerMoneyFormat.rupees(overpaidAmount)} above loan. '
          'Balance is ${LedgerMoneyFormat.rupees(balance)}.',
        ),
      ),
    );
  }

  Future<void> exportPdf(Map<String, dynamic> loanData) async {
    final ref = _ledgerService.loanRef(
      ledgerType: widget.ledgerType,
      loanId: widget.loanId,
    );

    final installmentsSnap =
        await ref.collection('installments').orderBy('date').get();

    final installments = installmentsSnap.docs.map((doc) {
      final pay = doc.data();
      final ts = pay['date'] as Timestamp;
      final d = ts.toDate();

      return {
        'date': '${d.day}/${d.month}/${d.year}',
        'amount': pay['amount'],
        'principalPaid': pay['principalPaid'],
        'interestPaid': pay['interestPaid'],
      };
    }).toList();

    await PdfService.generateLedgerPdf(
      loanData['name'].toString(),
      _asNum(loanData['principal']).toDouble(),
      _asNum(loanData['interestRate']).toDouble(),
      installments,
    );
  }

  Future<void> deleteInstallment(String installmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete installment?'),
        content: const Text(
          'Balances will be recalculated from remaining installments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _ledgerService.deleteInstallment(
      ledgerType: widget.ledgerType,
      loanId: widget.loanId,
      installmentId: installmentId,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Installment deleted')),
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  num _asNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final loanRef = _ledgerService.loanRef(
      ledgerType: widget.ledgerType,
      loanId: widget.loanId,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recalculate balances',
            onPressed: () async {
              setState(() => _syncing = true);
              await _syncBalances();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Balances updated')),
              );
            },
          ),
        ],
      ),
      floatingActionButton: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: loanRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();

          final data = snapshot.data!.data() ?? {};

          return FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Add Payment'),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddInstallmentScreen(
                    loanId: widget.loanId,
                    ledgerType: widget.ledgerType,
                    personName: data['name']?.toString() ?? '',
                    originalPrincipal: _asInt(data['principal']),
                    interestRate: _asInt(data['interestRate']),
                  ),
                ),
              );
              if (!mounted) return;
              setState(() => _syncing = true);
              await _syncBalances(notifyOverpay: true);
            },
          );
        },
      ),
      body: _syncing
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _syncBalances,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Breadcrumb(
                      items: [
                        BreadcrumbItem(
                          label: 'Home',
                          onTap: () =>
                              Navigator.popUntil(context, (r) => r.isFirst),
                        ),
                        BreadcrumbItem(
                          label: widget.listLabel,
                          onTap: () => Navigator.pop(context),
                        ),
                        BreadcrumbItem(label: 'Details'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: loanRef.snapshots(),
                      builder: (context, loanSnap) {
                        if (!loanSnap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final data = loanSnap.data!.data() ?? {};
                        final name = data['name']?.toString() ?? '—';
                        final principal = _asInt(data['principal']);
                        final rate = _asInt(data['interestRate']);
                        final remaining = _asInt(data['remainingPrincipal']);
                        final totalPaid = _asInt(data['totalPaid']);
                        final totalInterest = _asInt(data['totalInterestPaid']);
                        final overpaidAmount = remaining < 0 ? -remaining : 0;
                        final principalRepaid = remaining >= 0
                            ? principal - remaining
                            : principal;

                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: loanRef
                              .collection('installments')
                              .orderBy('date', descending: true)
                              .snapshots(),
                          builder: (context, instSnap) {
                            final docs = instSnap.data?.docs ?? [];

                            return ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: const Color(0xFF1E3A8A),
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '$rate% monthly interest on balance',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => exportPdf(data),
                                      icon: const Icon(Icons.picture_as_pdf),
                                      tooltip: 'Export PDF',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ProgressSummaryCard(
                                  title: 'Principal repayment',
                                  total: principal,
                                  paid: principalRepaid,
                                  remaining: remaining,
                                  progressColor: overpaidAmount > 0
                                      ? Colors.deepOrange.shade800
                                      : remaining == 0
                                          ? Colors.green.shade700
                                          : const Color(0xFF1E3A8A),
                                ),
                                if (overpaidAmount > 0)
                                  Container(
                                    margin: const EdgeInsets.only(top: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.deepOrange.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.deepOrange.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.warning_amber_rounded,
                                            color: Colors.deepOrange.shade800),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Overpayment detected',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.deepOrange.shade900,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Paid ${LedgerMoneyFormat.rupees(overpaidAmount)} more than the '
                                                '${LedgerMoneyFormat.rupees(principal)} principal. '
                                                'Current balance: ${LedgerMoneyFormat.rupees(remaining)}.',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.deepOrange.shade900,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else if (remaining == 0)
                                  Container(
                                    margin: const EdgeInsets.only(top: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle,
                                            color: Colors.green.shade700),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: Text(
                                            'Principal fully repaid. No overpayment.',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    StatCard(
                                      label: 'Total paid',
                                      value: LedgerMoneyFormat.rupees(totalPaid),
                                      icon: Icons.account_balance_wallet,
                                    ),
                                    const SizedBox(width: 10),
                                    StatCard(
                                      label: 'Interest paid',
                                      value: LedgerMoneyFormat.rupees(totalInterest),
                                      icon: Icons.percent,
                                      accentColor: Colors.orange.shade800,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    StatCard(
                                      label: 'To principal',
                                      value: LedgerMoneyFormat.rupees(principalRepaid),
                                      icon: Icons.savings,
                                      accentColor: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 10),
                                    StatCard(
                                      label: overpaidAmount > 0 ? 'Overpaid' : 'Balance',
                                      value: LedgerMoneyFormat.rupees(
                                        overpaidAmount > 0 ? overpaidAmount : remaining,
                                      ),
                                      icon: overpaidAmount > 0
                                          ? Icons.trending_down
                                          : Icons.account_balance,
                                      accentColor: overpaidAmount > 0
                                          ? Colors.red
                                          : null,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Payment history',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Each payment: monthly interest first, then principal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (docs.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Center(
                                      child: Text('No payments recorded yet'),
                                    ),
                                  )
                                else
                                  ...docs.map((doc) {
                                    final pay = doc.data();
                                    final ts = pay['date'] as Timestamp?;
                                    final date = ts?.toDate() ?? DateTime.now();

                                    return LedgerInstallmentTile(
                                      date: date,
                                      amount: _asInt(pay['amount']),
                                      interestPaid: _asInt(pay['interestPaid']),
                                      principalPaid: _asInt(pay['principalPaid']),
                                      principalApplied: _asInt(
                                        pay['principalApplied'],
                                      ),
                                      overpayment: _asInt(pay['overpayment']),
                                      remainingAfter: _asInt(
                                        pay['remainingAfter'],
                                      ),
                                      onDelete: () =>
                                          deleteInstallment(doc.id),
                                    );
                                  }),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
