import 'package:flutter/material.dart';
import '../../services/app_cache.dart';
import '../../services/dashboard_service.dart';
import '../../utils/ledger_calculator.dart';

class LedgerAnalyticsScreen extends StatefulWidget {
  const LedgerAnalyticsScreen({super.key});

  @override
  State<LedgerAnalyticsScreen> createState() => _LedgerAnalyticsScreenState();
}

class _LedgerAnalyticsScreenState extends State<LedgerAnalyticsScreen> {
  final DashboardService _dashboard = DashboardService();
  LedgerOverviewStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final cached = AppCache.instance.dashboardLedger;
    if (!force && cached != null) {
      setState(() {
        _stats = cached;
        _loading = false;
      });
    } else {
      setState(() => _loading = true);
    }

    try {
      final stats = await _dashboard.loadLedgerOverview(forceRefresh: force);
      if (mounted) setState(() => _stats = stats);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Ledger Analytics'),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _load(force: true)),
        ],
      ),
      body: _loading && stats == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _statTile(
                    'Total lent',
                    LedgerMoneyFormat.rupees(stats?.totalLentPrincipal ?? 0),
                    Icons.trending_up,
                    const Color(0xFF0F766E),
                  ),
                  _statTile(
                    'Total borrowed',
                    LedgerMoneyFormat.rupees(stats?.totalBorrowedPrincipal ?? 0),
                    Icons.trending_down,
                    const Color(0xFFDC2626),
                  ),
                  _statTile(
                    'Interest earned',
                    LedgerMoneyFormat.rupees(stats?.interestEarned ?? 0),
                    Icons.savings_outlined,
                    const Color(0xFF2563EB),
                  ),
                  _statTile(
                    'Interest paid',
                    LedgerMoneyFormat.rupees(stats?.interestPaid ?? 0),
                    Icons.payments_outlined,
                    const Color(0xFF7C3AED),
                  ),
                  _statTile(
                    'Net interest',
                    LedgerMoneyFormat.rupees(stats?.interestNet ?? 0),
                    Icons.account_balance_wallet_outlined,
                    const Color(0xFF047857),
                  ),
                  _statTile(
                    'Net position',
                    LedgerMoneyFormat.rupees(stats?.netPosition ?? 0),
                    Icons.balance,
                    const Color(0xFF1E3A8A),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(label),
      ),
    );
  }
}
